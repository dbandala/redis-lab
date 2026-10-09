# Lesson 06 — Sets

## Learning Objectives

By the end of this lesson you can:
- Store and query an unordered collection of unique members
- Compute intersections, unions, and differences across sets
- Explain the `intset` / `listpack` / `hashtable` encoding progression

## Concept

A **set** holds unique, unordered string members — a natural fit for tags, unique visitor IDs, or membership checks ("is this user in the beta group?").

Core commands: `SADD`, `SMEMBERS`, `SISMEMBER` (O(1) membership check — the main reason to reach for a set over a list), `SCARD` (count), `SPOP`/`SRANDMEMBER` (remove/peek a random member).

**Set algebra** is where sets earn their keep over lists: `SINTER a b` (members in both), `SUNION a b` (members in either), `SDIFF a b` (members in `a` but not `b`) — all computed server-side in one round trip, which is exactly the kind of thing you'd otherwise write awkward client-side loops for.

**Encoding:** a set of only small integers uses `intset` (a sorted array of integers — extremely compact). A set of short strings (or integers past the `set-max-intset-entries` limit) uses `listpack`. Once a set grows past `set-max-listpack-entries` (128 by default) or holds a long member, Redis converts it to `hashtable` for O(1) membership checks at scale.

**Try it:**
```
$ docker exec redis-foundations redis-cli SADD article:42:tags "redis" "database" "nosql"
(integer) 3
$ docker exec redis-foundations redis-cli SISMEMBER article:42:tags "redis"
(integer) 1
```

## Official Docs

- [SADD](https://redis.io/docs/latest/commands/sadd/)
- [SINTER](https://redis.io/docs/latest/commands/sinter/)

## Exercise

→ [exercises/06-sets/exercise.md](../exercises/06-sets/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101" includes a section comparing sets, sorted sets, and lists for similar-looking use cases.
