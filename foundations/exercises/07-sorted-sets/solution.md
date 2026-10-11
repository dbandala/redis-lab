# Solution 07 — Sorted Sets

```
$ docker exec redis-foundations redis-cli ZADD leaderboard:game1 100 alice 250 bob 75 carol
(integer) 3

$ docker exec redis-foundations redis-cli ZRANGE leaderboard:game1 0 -1 WITHSCORES
1) "carol"
2) "75"
3) "alice"
4) "100"
5) "bob"
6) "250"

$ docker exec redis-foundations redis-cli ZRANGE leaderboard:game1 0 -1 REV WITHSCORES
1) "bob"
2) "250"
3) "alice"
4) "100"
5) "carol"
6) "75"

$ docker exec redis-foundations redis-cli ZSCORE leaderboard:game1 bob
"250"
$ docker exec redis-foundations redis-cli ZRANK leaderboard:game1 alice
(integer) 1
```
`alice` is rank 1 (0-based) because `carol` (75) ranks below her ascending.

```
$ docker exec redis-foundations redis-cli ZINCRBY leaderboard:game1 50 carol
"125"
$ docker exec redis-foundations redis-cli ZRANGE leaderboard:game1 0 -1 WITHSCORES
1) "alice"
2) "100"
3) "carol"
4) "125"
5) "bob"
6) "250"
```
`carol` jumped from 75 to 125 and moved past `alice` in the ordering.

```
$ docker exec redis-foundations redis-cli OBJECT ENCODING leaderboard:game1
"listpack"
```

```
$ docker exec redis-foundations redis-cli ZADD leaderboard:game1 GT 10 bob
(integer) 0
$ docker exec redis-foundations redis-cli ZSCORE leaderboard:game1 bob
"250"
```
`ZADD` returned `0` (no new elements added, and no score changed) because `10` is not greater than `bob`'s existing score of `250` — the `GT` flag blocked the update. His score is still `250`.
