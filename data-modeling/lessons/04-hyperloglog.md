# Lesson 04 — HyperLogLog

## Learning Objectives

By the end of this lesson you can:
- Use `PFADD`/`PFCOUNT`/`PFMERGE` to track approximate unique counts without storing the actual members
- Explain HyperLogLog's trade-off: ~0.81% standard error in exchange for a near-fixed, tiny memory footprint
- Recognize when an approximate count is good enough (unique visitors) and when it isn't (ticket inventory)

## Concept

Counting *distinct* visitors to an event with a `SET` means storing every visitor id — memory grows linearly with traffic. **HyperLogLog (HLL)** is a probabilistic data structure that estimates the number of distinct elements added to it, using a data structure whose size barely grows no matter how many elements you add — Redis caps a single HLL at a maximum of ~12KB, trading a small, bounded error (standard error ~0.81%) for that fixed cost.

It's backed internally by a Redis **string**, which is why `PFADD`/`PFCOUNT` operate on an ordinary key — there's no new `TYPE` to learn.

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt100:visitors:2026-10-08 user:1 user:2 user:3 user:4 user:5
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt100:visitors:2026-10-08
(integer) 5
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt100:visitors:2026-10-08 user:3 user:4 user:6
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt100:visitors:2026-10-08
(integer) 6
```

Re-adding `user:3` and `user:4` (already counted) alongside new `user:6` correctly bumps the count by only 1 — HLL doesn't need to store *which* visitors it's seen to know whether one is new; it's estimating from hashed bit patterns, not from a membership list. At this small scale the estimate happens to be exact; the ~0.81% error only becomes visible at scale (thousands+ of distinct elements), and you can't inspect *which* elements are "in" an HLL the way you can list a set's members — that's the trade you're making.

`PFCOUNT` across multiple keys returns the estimated size of their **union** without merging anything:

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt100:visitors:2026-10-09 user:4 user:7 user:8
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt100:visitors:2026-10-08 hll:event:evt100:visitors:2026-10-09
(integer) 8
```

Day 1 has 6 distinct visitors, day 2 has 3, but `user:4` visited both days — so the two-day union is 8, not 9. To keep a running, queryable "all-time unique visitors" key instead of re-unioning daily keys on every read, merge them with `PFMERGE`:

```
$ docker exec redis-data-modeling redis-cli PFMERGE hll:event:evt100:visitors:total hll:event:evt100:visitors:2026-10-08 hll:event:evt100:visitors:2026-10-09
OK
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt100:visitors:total
(integer) 8
$ docker exec redis-data-modeling redis-cli STRLEN hll:event:evt100:visitors:total
(integer) 40
```

Only 40 bytes for this tiny example — Redis uses a compact **sparse** encoding while an HLL has few elements, and only promotes it to the ~12KB **dense** encoding once enough distinct elements have been seen to need the full precision structure. Either way, the size is nowhere close to what a `SET` holding the same visitor ids would cost once you're tracking millions of them.

## Official Docs

- [PFADD](https://redis.io/docs/latest/commands/pfadd/)
- [PFCOUNT](https://redis.io/docs/latest/commands/pfcount/)
- [PFMERGE](https://redis.io/docs/latest/commands/pfmerge/)

## Exercise

→ [exercises/04-hyperloglog/exercise.md](../exercises/04-hyperloglog/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — probabilistic data structures (HyperLogLog, and the Bloom/Top-K/Count-Min filters you'll meet in Level 3) are covered together in "RU102: Redis for Data Engineers."
