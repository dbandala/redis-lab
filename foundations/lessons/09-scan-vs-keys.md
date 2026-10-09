# Lesson 09 — SCAN vs KEYS

## Learning Objectives

By the end of this lesson you can:
- Explain why `KEYS` is dangerous in production but `SCAN` is safe
- Iterate a keyspace to completion using `SCAN`'s cursor
- Use the type-specific scan variants `HSCAN`/`SSCAN`/`ZSCAN`

## Concept

`KEYS pattern` returns every matching key in the entire keyspace **in a single call**, and because Redis is single-threaded (Lesson 01), that one call blocks every other client for as long as it takes to scan the whole keyspace. On a demo database with a few dozen keys, that's instant. On a production database with millions of keys, it can stall your entire Redis instance for seconds — an outage you caused with a read command. **Rule for this course and beyond: `KEYS` is for ad-hoc exploration in a throwaway `redis-cli` session only. Never call it from application code, and never run it against a shared/production database.**

`SCAN cursor [MATCH pattern] [COUNT hint]` is the safe alternative. Instead of one giant blocking call, you make a series of small, cheap calls: each call takes a cursor (start with `0`) and a `COUNT` hint (roughly how many keys to inspect per call — a hint, not a hard limit), and returns a **new cursor** plus a batch of keys. You keep calling `SCAN` with the cursor it just gave you until it returns cursor `0`, which signals you've covered the whole keyspace. Each individual call is fast and non-blocking, so other clients keep getting served in between.

Trade-off to know: `SCAN` provides only a weaker guarantee than `KEYS` — a key that exists for the entire scan is guaranteed to be returned at least once, but you may see some keys more than once, and keys added/removed mid-scan may or may not appear. For nearly every real use case (deleting expired-pattern keys, building an admin tool, migrating data) that guarantee is exactly what you need, and the production-safety trade-off is worth it.

The same cursor-based approach exists per-type for iterating within a single hash, set, or sorted set: `HSCAN key cursor`, `SSCAN key cursor`, `ZSCAN key cursor` — useful once a single hash/set/zset itself grows too large to read back in one `HGETALL`/`SMEMBERS`/`ZRANGE` call.

**Try it (against 50 seeded demo keys):**
```
$ docker exec redis-foundations redis-cli SCAN 0 MATCH "demo:*" COUNT 10
68
1) "demo:key:41"
2) "demo:key:11"
...
```
The first line (`68`) is the cursor to pass into your *next* `SCAN` call. Keep going until you get back `0`.

## Official Docs

- [SCAN](https://redis.io/docs/latest/commands/scan/)
- [KEYS](https://redis.io/docs/latest/commands/keys/)

## Exercise

→ [exercises/09-scan-vs-keys/exercise.md](../exercises/09-scan-vs-keys/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101" has a module specifically on safe keyspace iteration patterns for production.
