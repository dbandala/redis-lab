# Solution 06 — Eviction Policies & Memory Management

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory 3mb
OK
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory-policy allkeys-lfu
OK
```

```
$ for i in $(seq 1 15000); do redis-cli SET pulse:cache:$i "<~70 chars>" > /dev/null; done
$ docker exec redis-architecture-and-operations redis-cli DBSIZE
(integer) 12028
$ docker exec redis-architecture-and-operations redis-cli INFO stats | grep evicted_keys
evicted_keys:3172
```
Not every key survived: 15,000 `SET`s went in, but only ~12,000 fit under the 3MB cap at once — the other ~3,000 were evicted as capacity filled up. (Exact numbers will vary run to run — allocator overhead and timing aren't perfectly deterministic — but the shape is the same: writes succeed, older/colder entries quietly disappear.)

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET maxmemory-policy volatile-ttl
OK
$ docker exec redis-architecture-and-operations redis-cli INFO keyspace
db0:keys=11206,expires=0,avg_ttl=0,subexpiry=0
$ docker exec redis-architecture-and-operations redis-cli SET pulse:cache:newkey "val" EX 60
(error) OOM command not allowed when used memory > 'maxmemory'.
```
`expires=0` — not one of the 11,206 surviving keys has a TTL, even though we're at `maxmemory`. `volatile-ttl` can only evict keys that have an expiry set; with zero eligible candidates, it has no way to free room, so it behaves exactly like `noeviction` here: every new write is rejected with OOM until either `maxmemory` is raised, the policy changes, or some keys actually get TTLs.

```
$ for i in $(seq 1 1000); do redis-cli EXPIRE pulse:cache:<a-key-you-just-wrote> 300 > /dev/null; done
$ docker exec redis-architecture-and-operations redis-cli INFO keyspace
db0:keys=10888,expires=632,avg_ttl=299821,subexpiry=0
$ docker exec redis-architecture-and-operations redis-cli SET pulse:cache:newkey "val" EX 60
OK
```
Note `expires=632`, not `1000` — some of the keys targeted by the `EXPIRE` loop had already been evicted by the time the loop ran (LFU eviction is frequency-based and approximate, not strictly oldest-first, so it can and does evict recently-written keys alongside old ones). Once *some* keys had a TTL, `volatile-ttl` had eligible candidates again and the write succeeded.

```
$ docker exec redis-architecture-and-operations redis-cli MEMORY USAGE pulse:cache:newkey
(integer) 56
```
56 bytes for a 3-character value isn't a bug — it's the fixed per-key overhead (the dict entry, the key's own SDS string, `robj` metadata) that exists no matter how small the value is. This is exactly why Lesson 06 opened by measuring real `used_memory` rather than eyeballing "it's just a few bytes" — overhead dominates for small values.

**Step 6:** `allkeys-lfu` protects the popular event pages better. `allkeys-lru` tracks *recency*, not frequency — a burst of thousands of one-off idempotency tokens written and read exactly once would all register as "most recently used," pushing genuinely popular (but not most-recently-touched) event pages toward eviction purely because of request timing, not actual value. `allkeys-lfu` tracks an access-frequency counter per key instead: an event page read constantly accumulates a high frequency count that a one-off token, accessed once, never approaches — so under memory pressure, LFU evicts the low-frequency one-off tokens first and keeps the genuinely hot event pages resident, which is the outcome Pulse actually wants.
