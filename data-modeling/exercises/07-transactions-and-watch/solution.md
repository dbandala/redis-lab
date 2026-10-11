# Solution 07 — Transactions: MULTI/EXEC/WATCH

```
$ docker exec redis-data-modeling redis-cli SET inventory:ticket:evt100:GA 20
OK
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
MULTI
DECRBY inventory:ticket:evt100:GA 3
HSET reservation:res_ex1 user_id 99 qty 3
EXEC
EOF
OK
QUEUED
QUEUED
1) (integer) 17
2) (integer) 2
```
Final inventory: `17` (`20 - 3`), confirmed with `GET`.

```
$ docker exec -i redis-data-modeling redis-cli --no-raw <<'EOF'
MULTI
DECRBY inventory:ticket:evt100:GA 10
DISCARD
EOF
OK
QUEUED
OK
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:GA
"17"
```
Still `17` — `DISCARD` threw away the queued `DECRBY` before it ever ran.

```
$ # terminal A
$ ./simulate-concurrent-update.sh inventory:ticket:evt100:GA 1 1
Waiting 1s before the concurrent update...
Decrementing inventory:ticket:evt100:GA by 1 from a second connection...
(integer) 16
$ # terminal B, started just before terminal A, paused ~2s before EXEC
$ docker exec -i redis-data-modeling redis-cli --no-raw
WATCH inventory:ticket:evt100:GA
OK
MULTI
OK
DECRBY inventory:ticket:evt100:GA 5
QUEUED
EXEC
(nil)
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:GA
"16"
```
`EXEC` returns `(nil)` — aborted. Terminal A's `DECRBY 1` (`17 → 16`) landed on the watched key before terminal B's `EXEC` ran, so `WATCH` caught the change and refused to apply the queued `DECRBY 5`. Inventory stays at `16`, not `11` and not `15` — the aborted transaction had zero effect, exactly as optimistic locking promises.

```
$ docker exec -i redis-data-modeling redis-cli --no-raw
WATCH inventory:ticket:evt100:GA
OK
MULTI
OK
DECRBY inventory:ticket:evt100:GA 5
QUEUED
EXEC
1) (integer) 11
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:GA
"11"
```
With no concurrent writer this time, nothing changes `inventory:ticket:evt100:GA` between `WATCH` and `EXEC`, so the transaction succeeds cleanly: `16 - 5 = 11`. This is the retry step a real client would run automatically after seeing the `nil` from task 4 — re-`WATCH`, re-queue against current state, `EXEC` again.
