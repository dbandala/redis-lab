# Lesson 03 — Caching Patterns: Cache-Aside & Write-Through

## Learning Objectives

By the end of this lesson you can:
- Implement the cache-aside (lazy-loading) pattern: check cache, fall back to the source of truth on a miss, populate the cache with a TTL
- Implement write-through: keep the cache updated in lockstep with every write, instead of waiting for the next read to repopulate it
- Explain the actual behavioral difference between the two (not just "they're both caching") and when each is the right default
- Recognize the stale-read window cache-aside has that write-through doesn't, and the write-amplification cost write-through has that cache-aside doesn't

## Concept

Every data type lesson so far treated Redis as *the* store. In a real system, Redis is almost always a **cache in front of** a slower, more durable store (a Postgres table of events, an S3-backed media catalog, etc.) — that other store is the **source of truth**, and Redis exists purely to absorb read traffic that store couldn't handle alone. This lesson models that explicitly: `pulse:db:event:*` plays the role of Pulse's "database" (a plain hash, standing in for a real external datastore), and `pulse:cache:event:*` is the Redis-side cache in front of it.

**Cache-aside** (a.k.a. lazy loading) is the default pattern: the application checks the cache first; on a miss, it reads the source of truth itself, writes what it found into the cache (with a TTL), and returns it. Redis never talks to the database — the *application* owns that fallback:

```python
def cache_aside_get_event(event_id):
    cache_key = f"pulse:cache:event:{event_id}"
    cached = r.hgetall(cache_key)
    if cached:
        return cached, "HIT"
    db_key = f"pulse:db:event:{event_id}"
    data = r.hgetall(db_key)
    if data:
        r.hset(cache_key, mapping=data)
        r.expire(cache_key, 30)
    return data, "MISS"
```

```
$ python3 -c "
import sys; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())
r.hset('pulse:db:event:evt1', mapping={'name': 'Night Lights Festival', 'price': '89.00'})
# ... cache_aside_get_event defined as above ...
print('first call:', cache_aside_get_event('evt1'))
print('TTL after first call:', r.ttl('pulse:cache:event:evt1'))
print('second call:', cache_aside_get_event('evt1'))
"
first call: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'MISS')
TTL after first call: 30
second call: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'HIT')
```

The first call is a `MISS` — the cache was empty, so the function read the "database" hash and populated the cache with a 30-second TTL. The second call is a `HIT` — straight from Redis, no database read at all. This is cache-aside's whole value proposition: the database only gets hit once per TTL window per key, no matter how many reads arrive in between.

Cache-aside's weak point: if the underlying data changes (someone updates the event's price directly in the database), the cache keeps serving the **old** value until its TTL expires. That's a real, bounded staleness window — acceptable for a lot of read-heavy data, not acceptable for data that must be correct the instant it changes (a displayed ticket price during checkout, for instance).

**Write-through** closes that gap: every write updates the cache *and* the source of truth together, so the cache is never stale — there's no window to wait out:

```python
def write_through_update_price(event_id, new_price):
    db_key = f"pulse:db:event:{event_id}"
    cache_key = f"pulse:cache:event:{event_id}"
    r.hset(db_key, "price", new_price)
    r.hset(cache_key, "price", new_price)
```

```
$ python3 -c "
# ... r, write_through_update_price defined as above, cache already warm from the cache-aside example ...
write_through_update_price('evt1', '99.00')
print('cache immediately after write-through:', r.hget('pulse:cache:event:evt1', 'price'))
print('TTL unaffected by write-through:', r.ttl('pulse:cache:event:evt1'))
"
cache immediately after write-through: 99.00
TTL unaffected by write-through: 30
```

Notice the TTL is untouched — write-through *updates* the existing cache entry in place; it doesn't need to re-fetch from the database or reset the expiry, because the application already has the new value in hand at write time. That's the actual mechanical difference verify.sh-style checks should assert, not just "a key exists": cache-aside only becomes correct again after its TTL lapses and the next read re-populates it; write-through is correct the instant the write call returns.

| | Cache-aside | Write-through |
|---|---|---|
| Who populates the cache | The next reader, on a miss | The writer, immediately |
| Staleness window after a DB change | Up to one TTL | None |
| Extra write cost | None (cache only touched on a miss) | Every write touches both stores |
| Cold-cache / never-read keys | Never cached (no wasted writes) | Cached anyway, even if nobody reads them |
| Good fit | Read-heavy, tolerant-of-brief-staleness data (event listings, search results) | Read-and-write, correctness-sensitive data (live inventory counts, prices mid-checkout) |

A third pattern, **write-behind** (acknowledge the write immediately, persist to the database asynchronously later), trades durability for write latency and is usually implemented with Lesson 05's reliable-queue pattern rather than a direct synchronous call — worth knowing the name, but Pulse doesn't use it: Pulse's database writes (ticket sales, price changes) need to be durable the moment they're acknowledged, not queued for eventual consistency.

One more failure mode worth naming here because Lesson 04 exists to fix it: under concurrent load, two cache-aside misses for the same key can both read the database and both write the cache at (nearly) the same time — harmless for idempotent reads, but if the "read" were instead "decrement the last ticket," that's the race Lesson 04's distributed lock is for.

## Official Docs

- [Redis for caching](https://redis.io/solutions/caching/)
- [EXPIRE](https://redis.io/docs/latest/commands/expire/)
- [HSET](https://redis.io/docs/latest/commands/hset/)

## Exercise

→ [exercises/03-cache-aside-and-write-through/exercise.md](../exercises/03-cache-aside-and-write-through/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" touches on caching strategy; AWS's and Redis's own caching pattern write-ups (linked above) go deeper on cache-aside/write-through/write-behind trade-offs than any single RU course does.
