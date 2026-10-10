# Lesson 09 — Lua Scripting and Redis Functions

## Learning Objectives

By the end of this lesson you can:
- Run an ad hoc atomic script with `EVAL`, and understand `KEYS[]`/`ARGV[]`
- Cache and re-run a script by hash with `SCRIPT LOAD`/`EVALSHA`, and recognize the `NOSCRIPT` error
- Load a named, persistent Function library with `FUNCTION LOAD` and call it with `FCALL`
- Choose between `WATCH`-based optimistic locking and a script/Function for a given atomicity problem

## Concept

Lesson 07's `WATCH` retry loop takes multiple round trips and can abort under contention. Lua scripting solves the same problem differently: Redis runs a whole script as a single atomic step, on the server, with no other client's commands interleaved — no `WATCH`, no retry loop, no aborted `EXEC`.

**`EVAL`** runs a script inline. `KEYS[]` and `ARGV[]` are how key names and plain arguments get into the script — Redis uses the declared `KEYS` list (not string-parsing the script) to know which keys a script touches, which matters for routing in Cluster:

```
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local qty=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current>=qty then redis.call('DECRBY',key,qty) return current-qty else return -1 end" 1 inventory:ticket:evt100:GA 3
(integer) 17
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local qty=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current>=qty then redis.call('DECRBY',key,qty) return current-qty else return -1 end" 1 inventory:ticket:evt100:GA 1000
(integer) -1
```

The read (`GET`) and the conditional write (`DECRBY`) happen inside one atomic script execution — no other client can decrement the same key between the check and the write, which is exactly the race `WATCH` exists to catch after the fact. Here the check happens *before* any write at all, so there's nothing to retry.

Sending the full script text on every call is wasteful once it's more than a few lines, so Redis supports caching it server-side by hash:

```
$ docker exec redis-data-modeling redis-cli SCRIPT LOAD "return redis.call('GET', KEYS[1])"
"d3c21d0c2b9ca22f82737626a27bcaf5d288f99f"
$ docker exec redis-data-modeling redis-cli EVALSHA d3c21d0c2b9ca22f82737626a27bcaf5d288f99f 1 inventory:ticket:evt100:GA
"17"
$ docker exec redis-data-modeling redis-cli SCRIPT FLUSH
OK
$ docker exec redis-data-modeling redis-cli EVALSHA d3c21d0c2b9ca22f82737626a27bcaf5d288f99f 1 inventory:ticket:evt100:GA
(error) NOSCRIPT No matching script. Please use EVAL.
```

That `NOSCRIPT` after `SCRIPT FLUSH` (or after a restart, or on a replica that hasn't seen the `SCRIPT LOAD`) is the classic cold-cache pitfall of `EVALSHA` — real clients handle it by catching `NOSCRIPT` and falling back to a full `EVAL`. This is exactly the problem **Redis Functions** (7.0+) remove.

**Functions** are named, versioned script libraries that Redis persists (RDB/AOF) and replicates like any other data — no cache to go cold, no hash to track client-side. A library is loaded once from a file with a `#!lua name=<libname>` header:

```lua
#!lua name=ticketlib
redis.register_function('reserve_ticket', function(keys, args)
  local key = keys[1]
  local qty = tonumber(args[1])
  local current = tonumber(redis.call('GET', key))
  if current == nil then
    return redis.error_reply('no such inventory key: ' .. key)
  end
  if current >= qty then
    redis.call('DECRBY', key, qty)
    return current - qty
  end
  return -1
end)
```

```
$ cat ticketlib.lua | docker exec -i redis-data-modeling redis-cli -x FUNCTION LOAD REPLACE
"ticketlib"
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:GA 5
(integer) 12
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:GA 1000
(integer) -1
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:NONEXISTENT 1
(error) no such inventory key: inventory:ticket:evt100:NONEXISTENT
```

`FCALL` calls a named function from an already-loaded library — no script text, no hash, nothing to go stale. `redis.error_reply(...)` returns a proper Redis error to the caller instead of a Lua-level failure.

**`WATCH`/retry vs. script/Function — which one for Pulse's reservation flow?**

| | `WATCH` + `MULTI`/`EXEC` retry loop | `EVAL`/Function |
|---|---|---|
| Round trips | Multiple (read, maybe retry) | One |
| Deployment | Pure client logic, nothing to load onto the server | Script/library must be written, tested, and loaded server-side |
| Behavior under high contention | More retries, more latency, possible starvation | No retries needed — scales better under contention |
| Best fit | Low-to-moderate contention, simple logic, no appetite for server-side code | High contention (e.g. a flash-sale ticket drop) or logic too complex to express safely as a retry loop |

For a ticket-launch flash sale — many clients racing the same inventory key in a tight window — a Function is the better fit, which is why the capstone uses `ticketlib.lua` for its reservation step.

## Official Docs

- [EVAL](https://redis.io/docs/latest/commands/eval/)
- [SCRIPT LOAD](https://redis.io/docs/latest/commands/script-load/)
- [FUNCTION LOAD](https://redis.io/docs/latest/commands/function-load/)
- [FCALL](https://redis.io/docs/latest/commands/fcall/)

## Exercise

→ [exercises/09-scripting-and-functions/exercise.md](../exercises/09-scripting-and-functions/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Data Engineers" includes a module on scripting and Functions, including the migration path from `EVAL` to `FUNCTION`.
