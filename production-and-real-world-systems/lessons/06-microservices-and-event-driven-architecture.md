# Lesson 06 — Redis in Microservices & Event-Driven Architectures

## Learning Objectives

By the end of this lesson you can:
- Choose between Pub/Sub and Streams for a given inter-service messaging need, based on durability and replay requirements rather than familiarity
- Identify the cache-invalidation problem that appears the moment more than one service shares a Redis cache
- Classify a piece of Pulse's data as belonging in Redis's "ephemeral tier" or as needing a durable system of record, and explain why that classification matters architecturally

## Concept

Every lesson so far has had one process talking to one Redis instance. A real Pulse deployment is a handful of independent services — an API, a notification sender, a fraud-detection worker, an analytics pipeline — all touching the same Redis instance for different reasons. That multi-service reality is where two decisions that looked academic in earlier levels start to have real consequences.

### Pub/Sub vs. Streams: durability is the decision, not habit

Level 2 introduced Pub/Sub (`PUBLISH`/`SUBSCRIBE`); Level 3 introduced Streams with consumer groups. Both let one event reach multiple interested parties — the difference that matters architecturally is what happens to a message **nobody was listening for when it was sent**:

```
$ docker exec redis-production-and-real-world-systems redis-cli PUBLISH pulse:events:test hello
(integer) 0
```

`PUBLISH` returns the number of subscribers that received the message — `0` here because nothing was subscribed. That message is simply gone; there is no log to replay it from, no consumer that can come back online five minutes later and catch up.

```
$ docker exec redis-production-and-real-world-systems redis-cli XADD pulse:stream:test '*' event hello
1791686126017-0
$ docker exec redis-production-and-real-world-systems redis-cli XLEN pulse:stream:test
(integer) 1
```

The equivalent `XADD` persists the event in the stream regardless of whether anyone was listening — a consumer group created *after* this `XADD` can still read it, because the event lives in the stream's log, not in a transient fan-out.

| | Pub/Sub | Streams + consumer groups |
|---|---|---|
| Message survives if no one's listening | No — dropped | Yes — durable in the log |
| Late/restarted consumer catches up | No | Yes (`XREADGROUP` resumes where it left off) |
| Multiple independent consumer groups off one event | Yes (every subscriber gets every message) | Yes, and each group tracks its own delivery position independently |
| Overhead | Minimal — no log to retain | A retained log (bounded with `MAXLEN`/`MINID` as covered in Level 3) |
| Right fit | Ephemeral signals nobody needs to replay (cache-invalidation pings, live presence/typing indicators) | Anything a service might need to reprocess, audit, or catch up on after downtime (order events, notifications, analytics ingestion) |

Pulse's VIP-claim notification (the capstone's job) is a Streams-or-reliable-queue case precisely because losing it silently is unacceptable — a confirmation email that never sends is a support ticket. A live "3 people are viewing this event" presence indicator on the other hand is a legitimate Pub/Sub use: if a message is missed, the next one (seconds later) supersedes it anyway, so durability would be pure overhead.

### Cache invalidation gets harder with more than one writer

Lesson 03's cache-aside and write-through patterns both assumed a single service owns writes to a given cache key. The moment a *second* service can also write to the same underlying data — Pulse's admin tool updating an event's price directly, independently of the API service that normally handles writes — write-through alone isn't enough unless **every** writer remembers to update the cache too. The common fix is to decouple invalidation from the write path entirely: a writer publishes an invalidation event (`PUBLISH pulse:invalidate:event:evt1` or an `XADD` to an invalidation stream, per the durability tradeoff above) instead of writing the cache itself, and every service with a local view of that cache subscribes and evicts on receipt. This trades "every writer must remember to update every cache" for "every writer must remember to announce it changed something" — a smaller, more consistently enforceable obligation, and the same fan-out shape as Lesson 01's dashboard watching `redis_keyspace_hits_total`/`misses_total` for the result.

### Redis as an ephemeral tier vs. a source of truth

The thread connecting Lessons 03–06: decide, for each piece of data, whether Redis is allowed to be the **only** place it lives, or whether it must always be recoverable from something durable underneath. A session token or a rate-limit counter can live in Redis alone — losing it is an inconvenience (a user re-logs-in; a limiter resets early), not data loss. A ticket sale, a payment confirmation, or a price change cannot — Redis caches a view of it, but something else (a relational database, in Pulse's case the `pulse:db:event:*` hashes standing in for one) must be the durable record cache-aside or write-through fall back to. Getting this classification wrong in either direction has a cost: treating ephemeral data as if it needs durability wastes engineering effort (AOF `always`, replication, backups — all solving a problem that didn't exist); treating durable-data needs as if Redis alone can satisfy them is how teams discover, usually during an incident, that the "source of truth" was actually a cache the whole time. Lesson 08 turns this same classification question into an explicit, repeatable decision framework.

## Official Docs

- [Redis Pub/Sub](https://redis.io/docs/latest/develop/interact/pubsub/)
- [Redis Streams](https://redis.io/docs/latest/develop/data-types/streams/)
- [Redis for caching](https://redis.io/solutions/caching/)

## Exercise

→ [exercises/06-microservices-and-event-driven-architecture/exercise.md](../exercises/06-microservices-and-event-driven-architecture/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU205: Streaming Data" is the deepest single resource on the Pub/Sub-vs-Streams decision this lesson covers.
