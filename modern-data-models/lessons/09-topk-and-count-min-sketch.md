# Lesson 09 — Top-K & Count-Min Sketch

## Learning Objectives

By the end of this lesson you can:
- Maintain a live "top N trending items" list with `TOPK`, without storing or sorting every item's exact count
- Estimate how often an arbitrary item occurred with `CMS`, in fixed memory regardless of how many distinct items there are
- Explain what each structure trades away (exactness) to get a fixed, predictable memory footprint

## Concept

"What are the top 3 trending events right now?" sounds like a job for a sorted set — and for a *bounded* number of events, it is (Level 2, Lesson 02). But "what are the top 3 search terms out of an unbounded, ever-growing stream of free-text queries, across millions of searches" is a different problem: you can't afford one sorted-set member per distinct search term ever typed. **Top-K** and **Count-Min Sketch** solve exactly this — fixed memory, no matter how many distinct items flow through.

### Top-K: who's winning right now

`TOPK.RESERVE` allocates a structure that only ever tracks its top *k* items, with internal sizing parameters (`width`, `depth`, `decay`) that trade a little accuracy for memory:

```
$ docker exec redis-modern-data-models redis-cli TOPK.RESERVE trending:events 3 50 5 0.9
OK
```

`3` = track the top 3. Feed it a stream of event views (repeats count as repeats — this mirrors a real view-event stream, not a deduplicated one):

```
$ docker exec redis-modern-data-models redis-cli TOPK.ADD trending:events evt100 evt100 evt100 evt200 evt300 evt300 evt300 evt300 evt400
1) (nil)
2) (nil)
3) (nil)
4) (nil)
5) (nil)
6) (nil)
7) (nil)
8) (nil)
9) "evt200"
```

`TOPK.ADD` returns one reply per item added: `nil` if nothing was evicted, or the name of whatever item got pushed out of the top-k to make room. The 9th add (`evt400`) evicted `evt200` — by that point `evt300` (4 views) and `evt100` (3 views) had already locked in two of the three slots, and `evt400` edged out `evt200` for the third.

```
$ docker exec redis-modern-data-models redis-cli TOPK.LIST trending:events WITHCOUNT
1) "evt300"
2) (integer) 4
3) "evt100"
4) (integer) 3
5) "evt400"
6) (integer) 1
$ docker exec redis-modern-data-models redis-cli TOPK.QUERY trending:events evt300 evt200 evt999
1) (integer) 1
2) (integer) 0
3) (integer) 0
```

`TOPK.QUERY` confirms `evt300` is in the current top-k (`1`) while `evt200` — evicted earlier — and `evt999` (never added) are not (`0`). Now simulate a sudden surge, like a push notification driving a burst of views to `evt200`:

```
$ docker exec redis-modern-data-models redis-cli TOPK.INCRBY trending:events evt200 10
1) "evt400"
$ docker exec redis-modern-data-models redis-cli TOPK.LIST trending:events WITHCOUNT
1) "evt200"
2) (integer) 11
3) "evt300"
4) (integer) 4
5) "evt100"
6) (integer) 3
```

One `TOPK.INCRBY` call reshuffled the leaderboard and evicted `evt400` — exactly the "what's trending *right now*" behavior a homepage widget wants, maintained without ever sorting a growing list yourself.

### Count-Min Sketch: how often did *this specific thing* happen

Top-K only answers "who's in the top k." If you need an actual (approximate) count for an arbitrary item — including items nowhere near the top — that's a **Count-Min Sketch**. `CMS.INITBYDIM` sizes the sketch directly (`width`, `depth` — bigger means more accurate, at more memory):

```
$ docker exec redis-modern-data-models redis-cli CMS.INITBYDIM search:queries 2000 7
OK
```

`CMS.INCRBY` increments counts for one or more items in a single call, and returns each item's new estimated count:

```
$ docker exec redis-modern-data-models redis-cli CMS.INCRBY search:queries "jazz night" 5 "rock" 2 "jazz night" 3
1) (integer) 5
2) (integer) 2
3) (integer) 8
```

`"jazz night"` was incremented twice in one call (`5`, then `3` more) and correctly reports `8` the second time. `CMS.QUERY` reads an estimate back without modifying it:

```
$ docker exec redis-modern-data-models redis-cli CMS.QUERY search:queries "jazz night" "rock" "never searched"
1) (integer) 8
2) (integer) 2
3) (integer) 0
```

A term that was never incremented correctly reads back `0` — Count-Min Sketch, like Top-K, can **overestimate** a count (from hash collisions with other items) but never **underestimate** one, the same one-directional-error guarantee Lesson 08's Bloom filter gives for membership.

> **Top-K vs. CMS vs. a sorted set — when each one.** Need an exact, exhaustive ranking of a *bounded* set of things (all events this month)? Sorted set. Need "just the current top N" out of a stream with unbounded distinct items (all search terms ever typed)? Top-K. Need "how many times did this *specific* arbitrary thing happen," without caring about ranking, and without storing a counter per distinct thing? Count-Min Sketch. All three answer "how often," but only the sorted set is exact — Top-K and CMS buy fixed memory with a small, one-directional (over-, never under-) counting error.

## Official Docs

- [TOPK.RESERVE](https://redis.io/docs/latest/commands/topk.reserve/)
- [TOPK.ADD](https://redis.io/docs/latest/commands/topk.add/)
- [CMS.INITBYDIM](https://redis.io/docs/latest/commands/cms.initbydim/)
- [CMS.INCRBY](https://redis.io/docs/latest/commands/cms.incrby/)
- [Top-K](https://redis.io/docs/latest/develop/data-types/probabilistic/top-k/)
- [Count-min sketch](https://redis.io/docs/latest/develop/data-types/probabilistic/count-min-sketch/)

## Exercise

→ [exercises/09-topk-and-count-min-sketch/exercise.md](../exercises/09-topk-and-count-min-sketch/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — the probabilistic-data-structures module of "RU102" covers Top-K and Count-Min Sketch sizing in more depth, alongside Bloom/Cuckoo/HyperLogLog.
