# Solution 02 — Leaderboards and Priority Queues

```
$ docker exec redis-data-modeling redis-cli ZADD leaderboard:fans:weekly:2026-41 10 fan:a 40 fan:b 25 fan:c 60 fan:d 15 fan:e
(integer) 5
$ docker exec redis-data-modeling redis-cli ZINCRBY leaderboard:fans:weekly:2026-41 50 fan:a
"60"
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:weekly:2026-41 0 -1 REV WITHSCORES
 1) "fan:d"
 2) "60"
 3) "fan:a"
 4) "60"
 5) "fan:b"
 6) "40"
 7) "fan:c"
 8) "25"
 9) "fan:e"
10) "15"
```
`fan:a` and `fan:d` are now tied at `60`. When scores tie, Redis breaks the tie by member name — reverse-lexicographic order in a `REV` listing — which is why `fan:d` sorts just ahead of `fan:a` here even though `a` < `d` alphabetically.

```
$ docker exec redis-data-modeling redis-cli ZREVRANK leaderboard:fans:weekly:2026-41 fan:d WITHSCORE
1) (integer) 0
2) "60"
```

```
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:weekly:2026-41 "+inf" "-inf" BYSCORE REV LIMIT 0 3 WITHSCORES
1) "fan:d"
2) "60"
3) "fan:a"
4) "60"
5) "fan:b"
6) "40"
```
Matches the first three entries of the full `REV` listing above — `fan:d`, `fan:a`, `fan:b`.

```
$ docker exec redis-data-modeling redis-cli ZRANGESTORE leaderboard:fans:weekly:2026-41:top3 leaderboard:fans:weekly:2026-41 0 2 REV
(integer) 3
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:weekly:2026-41:top3 0 -1 WITHSCORES
1) "fan:b"
2) "40"
3) "fan:a"
4) "60"
5) "fan:d"
6) "60"
```
`ZRANGESTORE` always stores the result in **ascending** score order regardless of the `REV` flag used to select it — that's why the copy reads low-to-high (`fan:b`, then the `fan:a`/`fan:d` tie) even though it was selected as "top 3 by `REV`."

```
$ docker exec redis-data-modeling redis-cli ZREMRANGEBYRANK leaderboard:fans:weekly:2026-41 0 1
(integer) 2
$ docker exec redis-data-modeling redis-cli ZCARD leaderboard:fans:weekly:2026-41
(integer) 3
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:weekly:2026-41 0 -1 REV WITHSCORES
1) "fan:d"
2) "60"
3) "fan:a"
4) "60"
5) "fan:b"
6) "40"
```
Ranks `0` and `1` (ascending order) are the two *lowest* scorers — `fan:e` (15) and `fan:c` (25) — so removing that range trims the set down to exactly the top 3, confirmed by `ZCARD` returning `3`.

```
$ docker exec redis-data-modeling redis-cli ZADD queue:support:priority 4 "ticket:a" 1 "ticket:b" 3 "ticket:c" 2 "ticket:d"
(integer) 4
$ docker exec redis-data-modeling redis-cli ZPOPMIN queue:support:priority 1
1) "ticket:b"
2) "1"
$ docker exec redis-data-modeling redis-cli ZPOPMIN queue:support:priority 1
1) "ticket:d"
2) "2"
```
`ticket:b` (priority `1`) pops first, then `ticket:d` (priority `2`) — lowest score first, which is exactly the "most urgent next" semantics a priority queue needs, independent of insertion order.
