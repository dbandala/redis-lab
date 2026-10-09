# Lesson 08 — TTL, Expiration, and Key Naming

## Learning Objectives

By the end of this lesson you can:
- Set, inspect, and conditionally update a key's expiration
- Duplicate a key with `COPY`
- Apply a consistent, colon-delimited key naming convention

## Concept

**TTL basics:** `EXPIRE key seconds` sets a key to auto-delete after N seconds; `TTL key` reads the remaining seconds (`-1` = no TTL, `-2` = key doesn't exist); `PERSIST key` removes a TTL, making the key permanent again; `EXPIREAT`/`PEXPIREAT` set an absolute expiration time instead of a relative one.

**Conditional TTL updates:** since Redis 7.0, `EXPIRE` (and family) accepts `NX`/`XX`/`GT`/`LT` flags:
- `NX` — set a TTL only if the key currently has none
- `XX` — set a TTL only if the key already has one
- `GT` — set a new TTL only if it's **greater than** the current one (i.e., only extend a TTL, never shorten it)
- `LT` — the opposite: only shorten a TTL, never extend it

`GT` is exactly what you want for something like "extend a session's expiry on activity, but never let a stray request accidentally shorten it."

**`COPY source destination`** duplicates a key (including its value and, unless you pass `REPLACE`, only if the destination doesn't already exist) — a clean built-in alternative to reading a value out and writing it back yourself.

**Key naming convention:** Redis has no built-in namespacing, but a colon-delimited convention is the universal community standard: `<object-type>:<id>[:<sub-resource>]` — e.g. `user:1001`, `session:abc123`, `cache:product:9001`, `article:42:tags`. This is exactly the convention used throughout this module's exercises. It pays off twice: it makes keys self-describing when you browse them (in `redis-cli` or RedisInsight), and it turns into a `MATCH` pattern for `SCAN` in the next lesson (e.g. `cache:*` to iterate every cache entry).

**Try it:**
```
$ docker exec redis-foundations redis-cli SET cache:product:9001 "cached-payload"
OK
$ docker exec redis-foundations redis-cli EXPIRE cache:product:9001 120
(integer) 1
$ docker exec redis-foundations redis-cli TTL cache:product:9001
(integer) 120
```

## Official Docs

- [EXPIRE](https://redis.io/docs/latest/commands/expire/)
- [TTL](https://redis.io/docs/latest/commands/ttl/)
- [COPY](https://redis.io/docs/latest/commands/copy/)

## Exercise

→ [exercises/08-ttl-and-key-naming/exercise.md](../exercises/08-ttl-and-key-naming/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — several courses reuse this same colon-delimited naming convention throughout their sample datasets.
