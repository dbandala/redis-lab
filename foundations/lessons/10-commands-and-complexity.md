# Lesson 10 — Commands and Complexity

## Learning Objectives

By the end of this lesson you can:
- Read the "Time complexity" line on any official Redis command page
- Classify a command as O(1), O(log N), or O(N) and explain what that means for your data model
- Measure, not just guess, that a full-range read is meaningfully slower than a bounded one

## Concept

Every command page on `redis.io/docs/latest/commands/` states its **time complexity** near the top (e.g. "Time complexity: O(1)"). This is the single most important habit from this whole Foundations module for avoiding production incidents: before you reach for a command in a hot path, check its complexity against the size your data structure could grow to.

**Rough classification of commands you've already used:**

| Complexity | Meaning | Examples from Lessons 3-9 |
|---|---|---|
| O(1) | Constant time, independent of collection size | `GET`, `SET`, `HGET`, `HSET` (single field), `SADD` (per element), `LPUSH`/`RPUSH`, `LLEN`, `SCARD`, `TTL`, `EXPIRE` |
| O(log N) | Grows slowly as the collection grows — safe at scale | `ZADD`, `ZSCORE`, `ZRANK` (sorted sets use a skiplist internally) |
| O(N) | Grows linearly with collection (or result) size — fine for small N, dangerous for large N | `LRANGE` (full range), `SMEMBERS`, `HGETALL`, `KEYS`, `SINTER`/`SUNION`/`SDIFF` (proportional to total elements across sets) |

The lesson isn't "never use O(N) commands" — `HGETALL` on a 5-field hash is perfectly fine. The lesson is: **know which of your commands scale with data size, and know how big that data can realistically get**, the same reasoning that made Lesson 09 reject `KEYS` in production.

**Try it — measure it, don't just believe it.** This lab seeds a 5,000-element list and compares reading all of it against reading a bounded slice, using `redis-cli -r N` to repeat a command N times against a live connection (isolating command cost from process-startup overhead):

```
$ ./seed-biglist.sh
Seeded biglist:demo with 5000 elements

$ time docker exec redis-foundations redis-cli -r 1000 LRANGE biglist:demo 0 -1 > /dev/null
2.07s total   (≈ 2.07 ms/call)

$ time docker exec redis-foundations redis-cli -r 1000 LRANGE biglist:demo 0 9 > /dev/null
0.28s total   (≈ 0.28 ms/call)
```
Reading the **full** 5,000-element list is roughly **7× slower** per call than reading a bounded 10-element slice of the same list — a direct, measured demonstration of O(N) vs. effectively-constant cost. On a list with a million elements instead of 5,000, that gap gets far more dramatic, and a full `LRANGE` could single-handedly stall the single-threaded server (Lesson 01) for other clients.

## Official Docs

- [Commands index](https://redis.io/docs/latest/commands/) — every page states its time complexity

## Exercise

→ [exercises/10-commands-and-complexity/exercise.md](../exercises/10-commands-and-complexity/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) covers data-structure-specific performance tuning in more depth in its intermediate-level courses.
