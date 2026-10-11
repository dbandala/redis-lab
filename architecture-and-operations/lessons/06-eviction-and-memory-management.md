# Lesson 06 — Eviction Policies & Memory Management

## Learning Objectives

By the end of this lesson you can:
- Set `maxmemory` and pick a `maxmemory-policy` deliberately, not by default
- Read `INFO memory`/`INFO stats` to see eviction actually happening, with real numbers
- Explain why a `volatile-*` policy can leave you just as stuck as `noeviction` if you forgot to set TTLs
- Use `MEMORY USAGE` to find out what a specific key actually costs

## Concept

Back on the single-node base stack (`docker compose up -d` from the module root) for this lesson. By default, `maxmemory` is `0` — unlimited, bounded only by the host — and `maxmemory-policy` is `noeviction`. That combination is fine until it isn't: an unbounded cache on a host with finite RAM is a slow-motion outage waiting for a traffic spike.

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET maxmemory
1) "maxmemory"
2) "0"
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET maxmemory-policy
1) "maxmemory-policy"
2) "noeviction"
```

Set a cap and a policy that evicts to make room instead of refusing writes:

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory 2mb
OK
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory-policy allkeys-lru
OK
```

Fill it past capacity and watch eviction happen in real time:

```
$ for i in $(seq 1 20000); do redis-cli SET pulse:fill:$i "0123456789...70-chars..." > /dev/null; done
$ docker exec redis-architecture-and-operations redis-cli DBSIZE
(integer) 2667
$ docker exec redis-architecture-and-operations redis-cli INFO memory | grep -E "used_memory:|maxmemory:"
used_memory:2097784
maxmemory:2097152
$ docker exec redis-architecture-and-operations redis-cli INFO stats | grep evicted_keys
evicted_keys:17334
```

20,000 `SET`s went in; only 2,667 keys fit in the 2MB cap at once — the other **17,334 were evicted** to make room, visible directly in `evicted_keys`. This is the number to alert on: a steadily climbing `evicted_keys` rate on a cache you expected to comfortably fit means either your cap is too small or your working set grew past it.

**The policy families, and what each actually does:**

| Policy | Evicts from | Selection | Use case |
|---|---|---|---|
| `noeviction` | nothing | — | writes fail with OOM once full; reads still work. Right for data you can never silently lose |
| `allkeys-lru` | any key | least-recently-used | general-purpose cache, no TTLs required |
| `allkeys-lfu` | any key | least-*frequently*-used | cache with a hot/cold skew (LFU survives "used once long ago" better than LRU) |
| `allkeys-random` | any key | random | cheap approximation when LRU/LFU tracking overhead isn't worth it |
| `volatile-lru`/`volatile-lfu`/`volatile-random` | only keys **with a TTL set** | same as above, but restricted to volatile keys | mixed workload: some keys must never be evicted (no TTL = protected), others are disposable cache entries |
| `volatile-ttl` | only keys with a TTL | soonest-to-expire first | similar to above, biased toward keys about to die anyway |

**The gotcha that catches people in production:** a `volatile-*` policy only has something to evict if keys actually *have* TTLs set. Watch what happens when every key in the dataset was written without `EX`/`PX`:

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory-policy volatile-lru
OK
$ docker exec redis-architecture-and-operations redis-cli INFO keyspace
db0:keys=2667,expires=0,avg_ttl=0,subexpiry=0
$ docker exec redis-architecture-and-operations redis-cli SET pulse:session:withTTL "value" EX 100
(error) OOM command not allowed when used memory > 'maxmemory'.
```

`expires=0` — none of the 2,667 keys have a TTL, so `volatile-lru` has nothing eligible to evict and behaves exactly like `noeviction`: full stop, OOM on every new write. Picking a `volatile-*` policy is a commitment to actually setting TTLs on the keys you want to be disposable — it isn't a free upgrade over `allkeys-*`, it's a different contract.

`MEMORY USAGE` answers "what does this one key cost," useful when hunting down what's actually consuming your budget:

```
$ docker exec redis-architecture-and-operations redis-cli MEMORY USAGE pulse:session:demo
(integer) 48
```

`MEMORY DOCTOR` gives free-text heuristic advice — handy to run by eye, but its wording varies by version/heuristic and isn't something to script an assertion against.

## Official Docs

- [Memory optimization](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/memory-optimization/)
- [Eviction policies](https://redis.io/docs/latest/develop/reference/eviction/)
- [MEMORY USAGE](https://redis.io/docs/latest/commands/memory-usage/)
- [CONFIG SET maxmemory-policy](https://redis.io/docs/latest/commands/config-set/)

## Exercise

→ [exercises/06-eviction-and-memory-management/exercise.md](../exercises/06-eviction-and-memory-management/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Developers" covers memory optimization encodings (e.g. when a hash is stored as `listpack` vs `hashtable`) that compound with eviction policy choices on overall memory footprint.
