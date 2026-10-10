# Lesson 08 — Pub/Sub Messaging

## Learning Objectives

By the end of this lesson you can:
- Subscribe to a channel or a glob pattern with `SUBSCRIBE`/`PSUBSCRIBE`, and publish with `PUBLISH`
- Inspect active channels and subscriber counts with `PUBSUB CHANNELS`/`PUBSUB NUMSUB`
- Explain Pub/Sub's core caveat — messages are fire-and-forget, never persisted or acknowledged — and when that's fine versus when it isn't
- Recognize sharded Pub/Sub (`SSUBSCRIBE`/`SPUBLISH`) as the Cluster-aware variant

## Concept

When a Pulse ticket tier sells out, every connected client watching that event should know immediately. Pub/Sub is Redis's broadcast primitive for exactly this: publishers send a message to a named channel, and every currently-subscribed client gets a copy — no storage, no queue, no history.

```
$ docker exec -i redis-data-modeling redis-cli SUBSCRIBE "events:evt100:updates"
1) "subscribe"
2) "events:evt100:updates"
3) (integer) 1
```

That blocks, waiting for messages — run it in its own terminal. From a second terminal:

```
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt100:updates" "Gates open in 10 minutes"
(integer) 1
```

`PUBLISH` returns the number of subscribers that received it (`1`) — not an acknowledgment that anyone *processed* it. Back in the subscriber's terminal, the message arrives as a three-part push:

```
1) "message"
2) "events:evt100:updates"
3) "Gates open in 10 minutes"
```

`PSUBSCRIBE` matches a glob pattern instead of one exact channel — useful if Pulse wants "every update for every event" without subscribing to each event's channel individually:

```
$ docker exec -i redis-data-modeling redis-cli PSUBSCRIBE "events:*:updates"
1) "psubscribe"
2) "events:*:updates"
3) (integer) 1
```
```
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt200:updates" "VIP tickets just sold out"
(integer) 1
```
```
1) "pmessage"
2) "events:*:updates"
3) "events:evt200:updates"
4) "VIP tickets just sold out"
```

A pattern subscriber's push includes both the pattern it matched (`events:*:updates`) and the actual channel the message went to (`events:evt200:updates`), since one pattern can match many channels.

`PUBSUB` introspects the server's Pub/Sub state without subscribing to anything:

```
$ docker exec redis-data-modeling redis-cli PUBSUB CHANNELS
1) "events:evt100:updates"
$ docker exec redis-data-modeling redis-cli PUBSUB NUMSUB "events:evt100:updates"
1) "events:evt100:updates"
2) (integer) 1
```

**The caveat that matters:** Pub/Sub has no memory. If no one is subscribed when a message is published, it's gone — a client that connects a second later never sees it, there's no backlog to replay, and a subscriber's dropped connection silently misses everything sent while it was down. That's fine for "gates open in 10 minutes" (a late client will see the *next* notice) and wrong for "your payment succeeded" (which needs guaranteed delivery — that's what Redis Streams, in Level 3, are for).

**Aside — sharded Pub/Sub.** Redis 7 added `SSUBSCRIBE`/`SPUBLISH`/`SUNSUBSCRIBE` for Redis Cluster: regular Pub/Sub messages are broadcast to every node in a cluster regardless of which node receives the `PUBLISH`, which doesn't scale with cluster size. Sharded Pub/Sub instead routes a channel's traffic only to the node(s) actually holding subscribers for it, based on the channel name's hash slot — same message-delivery semantics as regular Pub/Sub, just scoped to one shard. A single-node lab like this one can't show the scaling difference, only the syntax (`SSUBSCRIBE channel` / `SPUBLISH channel message`) — it matters once you're running Cluster in Level 4.

## Official Docs

- [SUBSCRIBE](https://redis.io/docs/latest/commands/subscribe/)
- [PUBLISH](https://redis.io/docs/latest/commands/publish/)
- [PSUBSCRIBE](https://redis.io/docs/latest/commands/psubscribe/)
- [PUBSUB](https://redis.io/docs/latest/commands/pubsub/)

## Exercise

→ [exercises/08-pubsub/exercise.md](../exercises/08-pubsub/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102" covers Pub/Sub alongside Streams, with a direct comparison of their delivery guarantees.
