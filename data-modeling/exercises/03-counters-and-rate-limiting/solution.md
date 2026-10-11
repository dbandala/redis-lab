# Solution 03 — Counters and Rate Limiting

```
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:7:w0
(integer) 1
$ docker exec redis-data-modeling redis-cli EXPIRE ratelimit:fixed:user:7:w0 30 NX
(integer) 1
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:7:w0
(integer) 2
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:7:w0
(integer) 3
```
The count exceeds the limit of `2` on the **third** call — `INCR` returns `3`, and `3 > 2` is the application's cue to reject that request (Redis itself doesn't reject anything; it just reports the count honestly).

```
$ docker exec redis-data-modeling redis-cli EXPIRE ratelimit:fixed:user:7:w0 30 NX
(integer) 0
$ docker exec redis-data-modeling redis-cli TTL ratelimit:fixed:user:7:w0
(integer) 30
```
The second `EXPIRE ... NX` returns `0` (no-op) because the key already has a TTL — `NX` means "only set an expiry if none exists yet." Without `NX`, a stray second `EXPIRE` call (e.g. from a retried request) would push the window's end further into the future every time, letting a caller keep the window open indefinitely.

```
$ docker exec redis-data-modeling redis-cli ZADD ratelimit:sliding:user:7 1000 "req:1000:1" 1004 "req:1004:2" 1008 "req:1008:3" 1012 "req:1012:4"
(integer) 4
$ docker exec redis-data-modeling redis-cli ZREMRANGEBYSCORE ratelimit:sliding:user:7 "-inf" "(1002"
(integer) 1
$ docker exec redis-data-modeling redis-cli ZCARD ratelimit:sliding:user:7
(integer) 3
$ docker exec redis-data-modeling redis-cli ZRANGE ratelimit:sliding:user:7 0 -1 WITHSCORES
1) "req:1004:2"
2) "1004"
3) "req:1008:3"
4) "1008"
5) "req:1012:4"
6) "1012"
```
With the most recent timestamp at `1012` and a 10-second window, the cutoff is `1002`; the entry at `1000` falls strictly before it and gets pruned, leaving the 3 entries at `1004`, `1008`, and `1012` — exactly what `ZCARD` reports.

A unique member per request is required because a sorted set has **one entry per distinct member** — `ZADD` on an existing member updates its score instead of adding a new entry. If the member were just the timestamp, two requests landing in the same second would collapse into a single entry instead of counting as two separate requests, silently undercounting the caller's actual request rate.
