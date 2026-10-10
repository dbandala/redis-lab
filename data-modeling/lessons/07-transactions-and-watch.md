# Lesson 07 — Transactions: MULTI/EXEC/WATCH

## Learning Objectives

By the end of this lesson you can:
- Queue and run a batch of commands atomically with `MULTI`/`EXEC`, and cancel a queued batch with `DISCARD`
- Use `WATCH` for optimistic locking: detect a concurrent change and abort before `EXEC` applies anything
- Explain what `MULTI`/`EXEC` does and does **not** give you (no rollback on a runtime error inside the batch)

## Concept

Pulse needs ticket reservations to be atomic: decrement inventory and record the reservation together, or not at all. `MULTI` starts queuing commands on the current connection; each queued command replies `QUEUED` instead of running immediately; `EXEC` runs the whole batch back-to-back, with no other client's commands interleaved in between.

```
$ docker exec redis-data-modeling redis-cli SET inventory:ticket:evt100:VIP 10
OK
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
MULTI
DECRBY inventory:ticket:evt100:VIP 2
HSET reservation:res_demo1 user_id 42 qty 2
EXEC
EOF
OK
QUEUED
QUEUED
1) (integer) 8
2) (integer) 2
```

`EXEC`'s reply is an array of each queued command's own reply, in order — here `8` (the new inventory count) and `2` (the hash field count from `HSET`). `DISCARD` throws away a queued batch instead of running it:

```
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
MULTI
DECRBY inventory:ticket:evt100:VIP 5
DISCARD
EOF
OK
QUEUED
OK
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:VIP
"8"
```

Inventory is still `8` — the queued `DECRBY` never ran.

**`WATCH` adds optimistic locking**: watch one or more keys, and if *any* watched key changes between `WATCH` and `EXEC` (by any client), `EXEC` aborts and returns a null reply instead of running the batch — nothing in the batch takes effect. This demo starts inventory at `8`, has a second client decrement it by `1` mid-transaction, then tries to `EXEC` a transaction that assumed inventory was still `8`:

```
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
WATCH inventory:ticket:evt100:VIP
MULTI
DECRBY inventory:ticket:evt100:VIP 2
EXEC
EOF
OK
OK
QUEUED
(nil)
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:VIP
"7"
```

`EXEC` returned `(nil)` — the transaction was aborted, and the `DECRBY 2` never applied, because a second client's `DECRBY 1` landed on the watched key first (inventory went `8 → 7` from that other decrement alone). The caller's job is to detect the `nil` and retry: re-`WATCH`, re-read, re-queue, re-`EXEC`. Retrying against the current state of `7` succeeds cleanly:

```
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
WATCH inventory:ticket:evt100:VIP
MULTI
DECRBY inventory:ticket:evt100:VIP 2
EXEC
EOF
OK
OK
QUEUED
1) (integer) 5
```

This retry loop — `WATCH` → read → `MULTI`/queue/`EXEC` → on `nil`, retry — is **optimistic locking**: assume no conflict, detect it cheaply if wrong, and only pay the cost of retrying when contention actually happens.

**What `MULTI`/`EXEC` does *not* give you:** it's not a rollback mechanism. If one queued command is malformed (wrong number of arguments — a bug caught at queue time) the whole batch is rejected before `EXEC` runs anything. But if a command is syntactically valid and queues fine, then fails for a data reason at run time (e.g. `INCR` on a key holding a non-numeric string), `EXEC` still runs every other queued command — there's no partial-transaction rollback. Design your batches so each command can't fail for data reasons, or check preconditions before queuing.

## Official Docs

- [MULTI](https://redis.io/docs/latest/commands/multi/)
- [EXEC](https://redis.io/docs/latest/commands/exec/)
- [DISCARD](https://redis.io/docs/latest/commands/discard/)
- [WATCH](https://redis.io/docs/latest/commands/watch/)

## Exercise

→ [exercises/07-transactions-and-watch/exercise.md](../exercises/07-transactions-and-watch/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101" covers `MULTI`/`EXEC`/`WATCH` as part of its transactions module, including the retry-loop pattern used above.
