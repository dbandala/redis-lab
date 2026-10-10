# Lesson 07 — Consumer Groups & Reliable Processing

## Learning Objectives

By the end of this lesson you can:
- Create a consumer group and have multiple consumers split work from one stream without double-processing
- Explain the pending entries list (PEL) and why `XACK` is the step that makes processing "count"
- Recover a crashed consumer's unacknowledged work with `XCLAIM`/`XAUTOCLAIM`

## Concept

Lesson 06's `XREAD` is "catch me up since this ID" — fine for one reader, but with multiple workers pulling from the same stream, plain `XREAD` gives every worker every entry; nothing coordinates who handles what. A **consumer group** fixes that: Redis tracks, per group, which entries have been delivered to which named consumer and which are still unacknowledged — the same at-least-once delivery model Kafka consumer groups or SQS visibility timeouts provide, implemented as Stream-native commands.

`XGROUP CREATE` sets up a group at a starting position (`$` = only new entries from here); `MKSTREAM` creates the stream too if it doesn't exist yet:

```
$ docker exec redis-modern-data-models redis-cli XGROUP CREATE stream:pulse:orders grp:fulfillment $ MKSTREAM
OK
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders * event evt100 user u42 qty 2
"1791590987349-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders * event evt300 user u7 qty 1
"1791590987416-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders * event evt500 user u99 qty 3
"1791590987482-0"
```

A consumer reads with `XREADGROUP`, naming itself and the group, using `>` to mean "entries nobody in this group has been given yet":

```
$ docker exec redis-modern-data-models redis-cli XREADGROUP GROUP grp:fulfillment worker-1 COUNT 2 STREAMS stream:pulse:orders >
1) 1) "stream:pulse:orders"
   2) 1) 1) "1791590987349-0"
         2) 1) "event" 2) "evt100" ...
      2) 1) "1791590987416-0"
         2) 1) "event" 2) "evt300" ...
```

`worker-1` got the first two orders — and Redis now considers them **pending** for `worker-1` until acknowledged. `XPENDING` (summary form) shows exactly that:

```
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:orders grp:fulfillment
1) (integer) 2
2) "1791590987349-0"
3) "1791590987416-0"
4) 1) 1) "worker-1"
      2) "2"
```

Two pending entries, both assigned to `worker-1`. `XACK` tells Redis an entry was fully processed — it's not automatic, and that's the point: if the worker crashes mid-processing, the entry stays pending instead of silently disappearing:

```
$ docker exec redis-modern-data-models redis-cli XACK stream:pulse:orders grp:fulfillment 1791590987349-0
(integer) 1
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:orders grp:fulfillment
1) (integer) 1
2) "1791590987416-0"
3) "1791590987416-0"
4) 1) 1) "worker-1"
      2) "1"
```

Now say `worker-1` crashes before acking the second order. Another consumer can inspect *and take over* that stuck entry. The extended `XPENDING` form shows idle time (how long since it was delivered) per entry:

```
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:orders grp:fulfillment - + 10
1) 1) "1791590987416-0"
   2) "worker-1"
   3) (integer) 6454
   4) (integer) 1
```

`XCLAIM` reassigns a specific pending entry to a new consumer (the `0` here is a minimum-idle-time filter — `0` claims regardless of how long it's been pending, which is fine for this demo but you'd normally require some real idle threshold in production so you don't steal work from a consumer that's merely slow):

```
$ docker exec redis-modern-data-models redis-cli XCLAIM stream:pulse:orders grp:fulfillment worker-2 0 1791590987416-0
1) 1) "1791590987416-0"
   2) 1) "event" 2) "evt300" 3) "user" 4) "u7" 5) "qty" 6) "1"
```

`worker-2` now owns that entry and can process and `XACK` it. Meanwhile, `worker-2` can also just read whatever's new, same as `worker-1` did:

```
$ docker exec redis-modern-data-models redis-cli XREADGROUP GROUP grp:fulfillment worker-2 COUNT 10 STREAMS stream:pulse:orders >
1) 1) "stream:pulse:orders"
   2) 1) 1) "1791590987482-0"
         2) 1) "event" 2) "evt500" 3) "user" 4) "u99" 5) "qty" 6) "3"
```

`XAUTOCLAIM` is `XCLAIM` without having to know specific IDs upfront — scan the PEL for anything idle past a threshold and claim all of it in one call, which is what a real recovery job would run on a timer instead of manually naming IDs:

```
$ docker exec redis-modern-data-models redis-cli XAUTOCLAIM stream:pulse:orders grp:fulfillment worker-3 0 0
1) "0-0"
2) 1) 1) "1791590987416-0"
      2) 1) "event" 2) "evt300" ...
   2) 1) "1791590987482-0"
      2) 1) "event" 2) "evt500" ...
3) (empty array)
```

With both remaining entries acknowledged, `XPENDING` goes back to empty — no stuck work, nothing double-processed.

> **Redis Streams vs. Kafka, briefly.** Both give you an ordered, replayable log with consumer-group-based fan-out and at-least-once delivery. Kafka is a dedicated distributed system built for huge sustained throughput and long retention across a cluster of brokers; Redis Streams live inside Redis itself, sized by Redis's memory, and are the right call when you want log/queue semantics *alongside* data you're already keeping in Redis, without standing up and operating a separate system — not a drop-in replacement for Kafka at Kafka's scale.

## Official Docs

- [XGROUP](https://redis.io/docs/latest/commands/xgroup/)
- [XREADGROUP](https://redis.io/docs/latest/commands/xreadgroup/)
- [XACK](https://redis.io/docs/latest/commands/xack/)
- [XPENDING](https://redis.io/docs/latest/commands/xpending/)
- [XCLAIM](https://redis.io/docs/latest/commands/xclaim/)
- [XAUTOCLAIM](https://redis.io/docs/latest/commands/xautoclaim/)

## Exercise

→ [exercises/07-consumer-groups/exercise.md](../exercises/07-consumer-groups/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU204: Streams" has a full module on consumer groups and failure-recovery patterns.
