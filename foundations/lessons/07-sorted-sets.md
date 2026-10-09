# Lesson 07 — Sorted Sets

## Learning Objectives

By the end of this lesson you can:
- Maintain a score-ordered collection with `ZADD`/`ZRANGE`
- Read rank and score for a member, and increment a score atomically
- Use `ZADD`'s `GT`/`LT`/`NX`/`XX` flags for conditional score updates

## Concept

A **sorted set** (zset) is a set of unique members, each tagged with a floating-point **score**, kept continuously ordered by that score. It's the standard structure for leaderboards, priority queues, and anything ranked — you'll build a full leaderboard feature with it in Level 2; this lesson covers just the core mechanics.

Core commands: `ZADD key score member [score member ...]`, `ZRANGE key start stop [WITHSCORES] [REV]` (by rank, ascending by default; `REV` reverses to highest-first), `ZSCORE` (a member's score), `ZRANK` (a member's 0-based position, ascending), `ZINCRBY` (atomically add to a member's current score — the standard way to bump a leaderboard entry).

**Conditional score updates:** like `SET` and `EXPIRE`, `ZADD` accepts `GT`/`LT`/`NX`/`XX` flags. `ZADD key GT score member` only applies the update if the new score is **greater than** the member's current score — useful for "record a new high score, but never let a lower one overwrite it" without a client-side read-then-write.

**Encoding:** small sorted sets use `listpack`; once one grows past `zset-max-listpack-entries` (128 by default) or holds a long member, Redis converts it to `skiplist` — a structure that keeps `ZRANGE`/`ZRANK`/`ZADD` at O(log N) even at large scale.

**Try it:**
```
$ docker exec redis-foundations redis-cli ZADD leaderboard:game1 100 alice 250 bob 75 carol
(integer) 3
$ docker exec redis-foundations redis-cli ZRANGE leaderboard:game1 0 -1 WITHSCORES
1) "carol"
2) "75"
3) "alice"
4) "100"
5) "bob"
6) "250"
```

## Official Docs

- [ZADD](https://redis.io/docs/latest/commands/zadd/)
- [ZRANGE](https://redis.io/docs/latest/commands/zrange/)

## Exercise

→ [exercises/07-sorted-sets/exercise.md](../exercises/07-sorted-sets/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102" (Redis for Python/Java/etc.) builds a full leaderboard application on top of sorted sets, if you want to go deeper than this Foundations-level introduction.
