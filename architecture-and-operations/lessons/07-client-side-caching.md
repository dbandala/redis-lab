# Lesson 07 — Client-Side Caching with RESP3 Tracking

## Learning Objectives

By the end of this lesson you can:
- Explain what problem client-side caching solves that server-side caching (everything in prior lessons) doesn't
- Turn on `CLIENT TRACKING` over a RESP3 connection and watch Redis tell you, unprompted, when a key you read has changed
- Read the exact wire-level invalidation message Redis sends, not just a description of it

## Concept

Every lesson so far has been about Redis caching data *for* your application. Client-side caching flips that: your **application** caches data locally (in process memory — no network round trip at all), and Redis's job becomes just telling the application when its local copy is stale. For a value read thousands of times per second and written rarely — exactly Pulse's event-catalog pages — this is the difference between "fast" (a Redis round trip) and "effectively free" (an in-process memory read, with Redis only in the loop when something actually changes).

This requires **RESP3**, negotiated with `HELLO 3`, because the old RESP2 protocol has no mechanism for the server to push an unsolicited message to a client outside of Pub/Sub. RESP3 adds **push messages** — out-of-band frames the server can send a client at any time, independent of any request/response cycle — and `CLIENT TRACKING` uses exactly this to deliver invalidations.

**This lesson is genuinely interactive — read it at a real terminal, not by copy-pasting into a script.** Open two terminal windows side by side:

**Session A** (the "application" holding a local cache):
```
$ docker exec -it redis-architecture-and-operations redis-cli -3
127.0.0.1:6379> HELLO 3
... (connection now speaks RESP3) ...
127.0.0.1:6379> CLIENT TRACKING on
OK
127.0.0.1:6379> GET pulse:event:evt1
"Night Lights Festival"
```
`CLIENT TRACKING on` tells Redis: "remember every key I read from now on, and tell me if one changes." The `GET` both returns the value *and* registers `pulse:event:evt1` for tracking on this connection — this is the "default" tracking mode, where simply reading a key is what opts it in (there's also a `BCAST` broadcasting mode for tracking whole key prefixes without needing to read every key first).

**Session B** (some other client, or another part of your app, writing the same key):
```
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt1 "Downtown Art Walk"
OK
```

**Back in Session A**, without you typing anything, Redis pushes an invalidation message down the already-open connection. This is the part a piped/scripted terminal can't show you — `redis-cli` only services the socket for unsolicited push frames while genuinely sitting at an interactive prompt — so watch your own Session A window after running Session B's `SET`.

**What's actually on the wire.** To confirm exactly what gets sent (rather than just taking it on faith), here's the literal RESP3 bytes captured straight off the socket for the sequence above:
```
>2
$10
invalidate
*1
$16
pulse:event:evt1
```
`>2` is RESP3's push-type marker (2 elements follow): the literal string `invalidate`, then an array of the key name(s) that just went stale — here, one key, `pulse:event:evt1`. Your application's client library parses exactly this frame and is responsible for evicting `pulse:event:evt1` from its local cache the moment it arrives — Redis's job stops at notifying; it never reaches into your process's memory for you.

**Why this matters for Pulse specifically.** A naive local cache with a fixed TTL (say, 5 seconds) means every reader can serve data up to 5 seconds stale, and you're guessing at a TTL that trades staleness against Redis load either way. Client-side caching needs no TTL guess at all: cache a value in the application for as long as you want, and correctness is guaranteed by the invalidation push, not by a timer. Every major Redis client library (`redis-py`, `ioredis`, `Jedis`/`Lettuce`) implements this as an opt-in local-cache layer on top of the connection — you call a cache-enabling option, not the raw `CLIENT TRACKING` command yourself.

```
$ docker exec redis-architecture-and-operations redis-cli CLIENT TRACKINGINFO
 1) "flags"
 2) 1) "off"
 3) "redirect"
 4) (integer) -1
 5) "prefixes"
 6) (empty array)
```
Run on a connection that never enabled tracking — `flags: off` is the default; every connection is opted out until it explicitly asks for RESP3 + `CLIENT TRACKING on`.

## Official Docs

- [Client-side caching](https://redis.io/docs/latest/develop/clients/client-side-caching/)
- [CLIENT TRACKING](https://redis.io/docs/latest/commands/client-tracking/)
- [CLIENT TRACKINGINFO](https://redis.io/docs/latest/commands/client-trackinginfo/)
- [RESP3 protocol spec](https://redis.io/docs/latest/develop/reference/protocol-spec/)

## Exercise

→ [exercises/07-client-side-caching/exercise.md](../exercises/07-client-side-caching/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Developers" has a client-side caching module covering `BCAST` mode and the `redirect` option (tracking invalidations delivered to a separate connection, used by clients that can't easily receive out-of-band push messages on their main connection).
