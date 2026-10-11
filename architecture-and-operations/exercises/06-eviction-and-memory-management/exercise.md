# Exercise 06 — Eviction Policies & Memory Management

Run these against the base lab (`docker exec redis-architecture-and-operations redis-cli ...`). Start with `FLUSHALL` so earlier lessons' leftover keys don't skew your counts.

1. Set `maxmemory` to `3mb` and `maxmemory-policy` to `allkeys-lfu`.
2. Write keys `pulse:cache:1` through `pulse:cache:15000`, each with a ~70-character value (a shell loop calling `SET` is fine — see the lesson for the pattern). Check `DBSIZE` and `INFO stats`'s `evicted_keys` afterward. Did every key you wrote survive?
3. Switch `maxmemory-policy` to `volatile-ttl`. Check `INFO keyspace` — how many of your keys have a TTL (`expires=`)? Now try `SET pulse:cache:newkey "val" EX 60`. If `used_memory` (check `INFO memory`) isn't yet back over `maxmemory`, write more `pulse:cache:N` filler keys until it is, then retry. What error do you get, and why does having `expires=0` make it unavoidable under this specific policy?
4. Pick 1000 keys you're certain still exist (your most-recently-written ones are a safe bet, since `allkeys-lfu` eviction is approximate and can evict any low-frequency key regardless of age) and run `EXPIRE` on each with a 300-second TTL. Recheck `INFO keyspace`, then retry the `SET ... EX 60` from step 3. Does it succeed now?
5. Run `MEMORY USAGE` on the key you just created. Is the number surprising, given the value was just a few characters?
6. Conceptual: Pulse has two very different key spaces sharing one Redis instance — ticket-event detail pages (read constantly, re-read by the same popular events over and over) and one-off per-request idempotency tokens (written once, read at most once, never again). If both had to share a single `maxmemory` budget, would `allkeys-lru` or `allkeys-lfu` better protect the popular event pages from being evicted by a burst of one-off tokens? Why?

Check your answers against [solutions/06-eviction-and-memory-management/solution.md](../../solutions/06-eviction-and-memory-management/solution.md).
