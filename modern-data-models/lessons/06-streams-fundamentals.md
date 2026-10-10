# Lesson 06 — Redis Streams Fundamentals

## Learning Objectives

By the end of this lesson you can:
- Append events to a Redis Stream and read them back by range or by ID
- Explain Stream entry IDs and why they're both a timestamp and a sort key
- Cap a stream's size at write time so an unbounded event log doesn't grow forever

## Concept

Pub/Sub (Level 2, Lesson 08) is fire-and-forget: a message no subscriber is listening for is gone. Pulse Discover needs an **activity log** — every view and purchase, kept around so a consumer can catch up on history, replay from a point in time, or process events more than once if needed. That's what a Redis **Stream** is: an append-only log of entries, each with a unique, ordered ID, backed by a Redis-native data structure (not a wrapper around a list or a pub/sub channel).

`XADD` appends an entry — a set of field/value pairs, like a mini-hash — and returns the ID it was assigned:

```
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity * event evt100 action view user u42
"1791590884787-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity * event evt100 action purchase user u42 qty 2
"1791590884872-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity * event evt300 action view user u7
"1791590884946-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity * event evt500 action view user u99
"1791590885016-0"
```

The `*` asks Redis to auto-generate the ID. An ID is `<milliseconds-since-epoch>-<sequence>`: the timestamp Redis appended the entry, plus a sequence number to keep order even for entries added in the same millisecond. IDs are strictly increasing, which is what makes range queries by ID meaningful — unlike a sorted set's score, you don't choose this ordering, the log's write order *is* the ordering.

`XRANGE`/`XREVRANGE` read a range of entries by ID, with `-`/`+` meaning "the lowest/highest possible ID":

```
$ docker exec redis-modern-data-models redis-cli XRANGE stream:pulse:activity - +
1) 1) "1791590884787-0"
   2) 1) "event"
      2) "evt100"
      3) "action"
      4) "view"
      5) "user"
      6) "u42"
2) 1) "1791590884872-0"
   2) 1) "event"
      2) "evt100"
      3) "action"
      4) "purchase"
      ...
```

`XLEN` reports the entry count, and `XREAD` catches up on everything *after* a given ID — the core "read new stuff since last time I checked" primitive, which Lesson 07's consumer groups build on:

```
$ docker exec redis-modern-data-models redis-cli XLEN stream:pulse:activity
(integer) 4
$ docker exec redis-modern-data-models redis-cli XREAD COUNT 10 STREAMS stream:pulse:activity 1791590884787-0
1) 1) "stream:pulse:activity"
   2) 1) 1) "1791590884872-0"
         2) 1) "event"
            2) "evt100"
            3) "action"
            4) "purchase"
            ...
      2) 1) "1791590884946-0"
         ...
      3) 1) "1791590885016-0"
         ...
```

Passing an explicit ID to `XREAD` returns only entries *after* it (exclusive) — three entries here, not four, because the ID itself is excluded. `XREAD ... STREAMS key $` (using `$` instead of an ID) means "only entries added after this call" and, combined with `BLOCK <ms>`, turns `XREAD` into a long-poll — the basis for a consumer that waits for new activity instead of re-polling in a loop.

An unbounded log grows forever. `MAXLEN` on `XADD` trims the stream as part of the same write, keeping only the newest N entries:

```
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity MAXLEN 3 * event evt200 action view user u15
"1791590896634-0"
$ docker exec redis-modern-data-models redis-cli XLEN stream:pulse:activity
(integer) 3
```

Even though this was the 5th `XADD`, `XLEN` reports `3` — `MAXLEN 3` dropped the two oldest entries as part of appending the new one. `XINFO STREAM` reports metadata about the stream — length, the last-generated ID, and the first/last entries — useful for monitoring how far behind a log has grown or confirming a trim actually happened:

```
$ docker exec redis-modern-data-models redis-cli XINFO STREAM stream:pulse:activity
 1) "length"
 2) (integer) 3
...
 7) "last-generated-id"
 8) "1791590896634-0"
...
```

> **MAXLEN exact vs. approximate.** `MAXLEN 3` (shown above) trims to *exactly* 3 on every write, which costs a little CPU each time. `MAXLEN ~ 3` trims *approximately* — Redis waits until it can remove a whole internal macro-node at once, which is cheaper but can leave the stream briefly longer than 3. Production systems with high write volume typically use `~` for that reason; this lab uses the exact form so the entry count in the transcript matches exactly what you'd predict.

## Official Docs

- [XADD](https://redis.io/docs/latest/commands/xadd/)
- [XRANGE](https://redis.io/docs/latest/commands/xrange/)
- [XREAD](https://redis.io/docs/latest/commands/xread/)
- [Redis Streams](https://redis.io/docs/latest/develop/data-types/streams/)

## Exercise

→ [exercises/06-streams-fundamentals/exercise.md](../exercises/06-streams-fundamentals/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU204: Streams" covers the full Streams API, including consumer groups (next lesson).
