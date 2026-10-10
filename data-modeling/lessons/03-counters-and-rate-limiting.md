# Lesson 03 — Counters and Rate Limiting

## Learning Objectives

By the end of this lesson you can:
- Build a **fixed-window** rate limiter from `INCR` + `EXPIRE ... NX`
- Build a **sliding-window** rate limiter from a sorted set (`ZADD`/`ZREMRANGEBYSCORE`/`ZCARD`)
- Explain the trade-off between the two: fixed-window is cheaper but allows bursts at window boundaries; sliding-window is accurate but costs more memory and CPU

## Concept

A rate limiter answers one question: "has this caller made too many requests too recently?" Both approaches below are single-key-per-caller, so they also double as the per-user purchase limiter Pulse needs on ticket-launch night.

**Fixed window.** One counter per `(caller, window)`. First request in a window creates the key and starts its TTL; every request after that just increments:

```
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:42:w0
(integer) 1
$ docker exec redis-data-modeling redis-cli EXPIRE ratelimit:fixed:user:42:w0 60 NX
(integer) 1
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:42:w0
(integer) 2
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:42:w0
(integer) 3
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:42:w0
(integer) 4
```

With a limit of 3, the application rejects that 4th call because `INCR` returned `4 > 3` — the key itself was never at risk of overshooting, since `INCR` always returns the post-increment value atomically. `EXPIRE ... NX` (the `NX` flag is Redis 7+) sets the TTL **only if the key has no TTL yet**, so a crash or retry between `INCR` and `EXPIRE` can't accidentally reset the window's clock on every call.

The catch: a caller can make 3 requests at `0:59` and 3 more at `1:01` — 6 requests in 2 seconds, because those fall in two different fixed windows. That's the burst-at-the-boundary problem.

**Sliding window (log).** Instead of one counter, keep a timestamp per request in a sorted set, and count only the ones inside the trailing window:

```
$ docker exec redis-data-modeling redis-cli ZADD ratelimit:sliding:user:42 1791502342 "req:1791502342:1"
(integer) 1
$ docker exec redis-data-modeling redis-cli ZADD ratelimit:sliding:user:42 1791502344 "req:1791502344:3"
(integer) 1
$ docker exec redis-data-modeling redis-cli ZREMRANGEBYSCORE ratelimit:sliding:user:42 "-inf" "(1791502334"
(integer) 0
$ docker exec redis-data-modeling redis-cli ZCARD ratelimit:sliding:user:42
(integer) 3
```

Each request adds its own timestamp as both score and (uniquely-suffixed) member; `ZREMRANGEBYSCORE` prunes anything older than `now - window` before every check; `ZCARD` is the exact count of requests inside the trailing window, with no boundary effect. The cost: one `ZADD`, one `ZREMRANGEBYSCORE`, and one `ZCARD` per request instead of one `INCR` — and the set grows with request volume between prunes, not with a fixed footprint like the counter does.

**Which one for Pulse's purchase limiter?** Fixed-window, if occasional bursts at a minute boundary are an acceptable cost for a much cheaper check — this is almost always the right default. Sliding-window earns its extra cost only when the limiter is protecting something where a 2x momentary burst is a real problem (e.g. a strict per-second API quota tied to a billing agreement). Lesson 09 revisits this limiter as a single atomic Lua/Function call, removing the multi-round-trip race entirely.

## Official Docs

- [INCR](https://redis.io/docs/latest/commands/incr/)
- [EXPIRE](https://redis.io/docs/latest/commands/expire/)
- [ZADD](https://redis.io/docs/latest/commands/zadd/)
- [ZREMRANGEBYSCORE](https://redis.io/docs/latest/commands/zremrangebyscore/)
- [ZCARD](https://redis.io/docs/latest/commands/zcard/)

## Exercise

→ [exercises/03-counters-and-rate-limiting/exercise.md](../exercises/03-counters-and-rate-limiting/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — rate limiting is one of the worked examples in "RU102: Redis for Data Engineers."
