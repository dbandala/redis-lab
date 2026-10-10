# Lesson 02 — Leaderboards and Priority Queues

## Learning Objectives

By the end of this lesson you can:
- Use `ZRANGE` with `BYSCORE`/`REV`/`LIMIT` to page through a leaderboard from either end
- Get a member's rank and score with one round trip using `ZRANK`/`ZREVRANK ... WITHSCORE`
- Snapshot a slice of one sorted set into another with `ZRANGESTORE`, and trim a set with `ZREMRANGEBYRANK`
- Pop the lowest-scored member off a sorted set with `ZPOPMIN`/`ZPOPMAX` to drive a priority queue

## Concept

You already know `ZADD` and `ZINCRBY` from Level 1 — a sorted set keeps members ordered by score with O(log N) inserts. This lesson is about what you build once that ordering exists: **leaderboards** (highest score first) and **priority queues** (lowest score — soonest due, highest priority — first).

For Pulse, `leaderboard:fans:global` tracks fan engagement points. Reading a leaderboard is almost never "give me everything" — it's "give me the top N" or "where does this one fan rank":

- `ZRANGE key start stop REV WITHSCORES` — highest-to-lowest by index range
- `ZRANGE key max min BYSCORE REV LIMIT offset count WITHSCORES` — highest-to-lowest by score range, paginated
- `ZRANK key member WITHSCORE` / `ZREVRANK key member WITHSCORE` — a member's 0-based rank from the bottom or top, plus its score, in one call (the `WITHSCORE` option means you don't need a second `ZSCORE` round trip)
- `ZRANGESTORE dest key start stop REV` — write a ranked slice (e.g. "top 3") into its own key, atomically
- `ZREMRANGEBYRANK key start stop` — delete by rank range, e.g. trim a leaderboard to its top K by removing everything below

A **priority queue** is the same structure read from the other end: the *lowest* score is "next." `ZPOPMIN`/`ZPOPMAX` atomically remove and return that member — perfect for a worker pulling the next job.

**Try it:**

```
$ docker exec redis-data-modeling redis-cli ZADD leaderboard:fans:global 120 fan:ada 95 fan:grace 150 fan:linus 80 fan:margaret
(integer) 4
$ docker exec redis-data-modeling redis-cli ZINCRBY leaderboard:fans:global 30 fan:grace
"125"
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:global 0 -1 REV WITHSCORES
1) "fan:linus"
2) "150"
3) "fan:grace"
4) "125"
5) "fan:ada"
6) "120"
7) "fan:margaret"
8) "80"
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:global "+inf" "-inf" BYSCORE REV LIMIT 0 2 WITHSCORES
1) "fan:linus"
2) "150"
3) "fan:grace"
4) "125"
$ docker exec redis-data-modeling redis-cli ZREVRANK leaderboard:fans:global fan:grace WITHSCORE
1) (integer) 1
2) "125"
$ docker exec redis-data-modeling redis-cli ZRANGESTORE leaderboard:fans:top3 leaderboard:fans:global 0 2 REV
(integer) 3
$ docker exec redis-data-modeling redis-cli ZPOPMIN leaderboard:fans:global 1
1) "fan:margaret"
2) "80"
```

`fan:grace` is rank `1` from the top (0-indexed — `fan:linus` is rank `0`) with a score of `125` after the `ZINCRBY`. `ZRANGESTORE` copied the current top 3 into `leaderboard:fans:top3` without a client-side read-then-write round trip. `ZPOPMIN` removed the lowest scorer (`fan:margaret`) atomically — exactly the operation a priority-queue worker calls in a loop.

For a true priority queue (lower score = higher priority, e.g. a support ticket queue), the pattern is identical — just read from the bottom:

```
$ docker exec redis-data-modeling redis-cli ZADD queue:support:priority 3 "ticket:refund:501" 1 "ticket:outage:502" 2 "ticket:billing:503"
(integer) 3
$ docker exec redis-data-modeling redis-cli ZPOPMIN queue:support:priority 1
1) "ticket:outage:502"
2) "1"
```

The outage ticket (priority `1`) comes out first, even though it was added second — the sorted set, not insertion order, decides.

## Official Docs

- [ZADD](https://redis.io/docs/latest/commands/zadd/)
- [ZRANGE](https://redis.io/docs/latest/commands/zrange/)
- [ZRANK](https://redis.io/docs/latest/commands/zrank/)
- [ZRANGESTORE](https://redis.io/docs/latest/commands/zrangestore/)
- [ZREMRANGEBYRANK](https://redis.io/docs/latest/commands/zremrangebyrank/)
- [ZPOPMIN](https://redis.io/docs/latest/commands/zpopmin/)

## Exercise

→ [exercises/02-leaderboards-and-priority-queues/exercise.md](../exercises/02-leaderboards-and-priority-queues/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Streams" touches on queue patterns; Redis's own [client development patterns guide](https://redis.io/docs/latest/develop/use/patterns/) is also worth a look for more sorted-set-based use cases.
