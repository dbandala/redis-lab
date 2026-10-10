# Lesson 01 — Choosing the Right Structure

## Learning Objectives

By the end of this lesson you can:
- Match a real product problem (session store, counter, leaderboard, rate limiter) to the Redis data type that fits it best
- Explain why "it's just a key-value store" undersells Redis — the value's **type** is the actual design decision
- Recognize the running scenario for this module: **Pulse**, a live-event ticketing and fan-engagement platform, and how its data maps onto Redis types

## Concept

Level 1 taught you the five core types — strings, lists, hashes, sets, sorted sets — and the mechanics of each. Level 2 is about **picking the right one for a problem**, then layering patterns (rate limiting, atomicity, pub/sub) on top.

Throughout this module we'll build the hot-data layer for **Pulse**: ticket inventory, a fan leaderboard, purchase rate limiting, unique-visitor counts, daily-active-fan tracking, nearby-venue search, and live sold-out notifications. Every lesson adds one piece.

A quick decision framework — "what shape is the problem?":

| Problem shape | Redis type | Why |
|---|---|---|
| "One record, several named fields, expires together" (session, user profile) | **Hash** + `EXPIRE` | One key, O(1) field access, one TTL covers the whole record |
| "A running total" (page views, ticket count) | **String** + `INCR`/`INCRBY` | Atomic increment, no read-modify-write race |
| "Ranked members, need top-N or a member's rank" (leaderboard, priority queue) | **Sorted set** | Score-ordered by construction — Lesson 02 |
| "How many *distinct* things happened, don't need the list" (unique visitors) | **HyperLogLog** | Counts cardinality in ~12KB regardless of input size — Lesson 04 |
| "One bit of state per ID, millions of IDs" (daily-active flag per user) | **Bitmap** | 1 bit per user instead of a key per user — Lesson 05 |
| "Nearest N to a point" (nearby venues) | **Geospatial (sorted set under the hood)** | Radius/box queries for free — Lesson 06 |

**Try it** — the session-store pattern from Level 1, revisited as a hash (so a login session's user id, event id, and anything else about the session lives in one place with one TTL):

```
$ docker exec redis-data-modeling redis-cli HSET session:tok_9f8a user_id 42 event_id evt100
(integer) 2
$ docker exec redis-data-modeling redis-cli EXPIRE session:tok_9f8a 1800
(integer) 1
$ docker exec redis-data-modeling redis-cli TTL session:tok_9f8a
(integer) 1800
$ docker exec redis-data-modeling redis-cli HGETALL session:tok_9f8a
1) "user_id"
2) "42"
3) "event_id"
4) "evt100"
$ docker exec redis-data-modeling redis-cli INCR stats:pageviews:event:evt100
(integer) 1
$ docker exec redis-data-modeling redis-cli INCR stats:pageviews:event:evt100
(integer) 2
$ docker exec redis-data-modeling redis-cli TYPE session:tok_9f8a
hash
$ docker exec redis-data-modeling redis-cli TYPE stats:pageviews:event:evt100
string
```

A hash with a TTL beats a bag of separate `session:tok:user_id` / `session:tok:event_id` string keys: one `EXPIRE` instead of N, one round trip for `HGETALL` instead of N `GET`s, and the whole record disappears atomically when it expires.

## Official Docs

- [HSET](https://redis.io/docs/latest/commands/hset/)
- [EXPIRE](https://redis.io/docs/latest/commands/expire/)
- [INCR](https://redis.io/docs/latest/commands/incr/)
- [TYPE](https://redis.io/docs/latest/commands/type/)

## Exercise

→ [exercises/01-choosing-the-right-structure/exercise.md](../exercises/01-choosing-the-right-structure/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Data Engineers" and the data-modeling sections of "RU101" both go deeper on choosing a type for a workload.
