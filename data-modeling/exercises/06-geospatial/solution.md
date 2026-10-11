# Solution 06 — Geospatial Indexes

```
$ docker exec redis-data-modeling redis-cli GEOADD geo:venues:sf -122.4194 37.7749 "venue:a" -122.4180 37.7755 "venue:b" -122.2585 37.8044 "venue:c"
(integer) 3
$ docker exec redis-data-modeling redis-cli GEODIST geo:venues:sf venue:a venue:b km
"0.1401"
```
`venue:a` and `venue:b` are about 140 meters apart; `venue:c` is kilometers away across town.

```
$ docker exec redis-data-modeling redis-cli GEOSEARCH geo:venues:sf FROMMEMBER venue:a BYRADIUS 3 km ASC WITHDIST
1) 1) "venue:a"
   2) "0.0000"
2) 1) "venue:b"
   2) "0.1401"
```
`venue:c` is correctly excluded — only the two close venues fall inside the 3km radius.

```
$ docker exec redis-data-modeling redis-cli GEOSEARCH geo:venues:sf FROMMEMBER venue:a BYBOX 6 6 km ASC WITHDIST
1) 1) "venue:a"
   2) "0.0000"
2) 1) "venue:b"
   2) "0.1401"
```
Same result set here, because `venue:b` is close enough (140m) to fall well inside both the 3km circle and the 6x6km box. They *can* differ in general: a box's corners reach farther from the center than a circle of comparable "radius" does — a point could sit outside a 3km-radius circle but inside a 6x6km box (whose corners are `3√2 ≈ 4.24` km from center), or vice versa for a very thin/elongated box. With venues this far apart relative to the search sizes used here, that edge case doesn't show up.

```
$ docker exec redis-data-modeling redis-cli GEOSEARCHSTORE geo:venues:sf:nearby geo:venues:sf FROMMEMBER venue:a BYRADIUS 3 km ASC
(integer) 2
$ docker exec redis-data-modeling redis-cli ZRANGE geo:venues:sf:nearby 0 -1 WITHSCORES
1) "venue:a"
2) "1367859919124626"
3) "venue:b"
4) "1367859919318441"
```
The scores are **not** distances — they're the raw 52-bit geohash integers Redis uses internally to order the sorted set. To get actual distances back out of a geo key you need `GEODIST`/`GEOSEARCH WITHDIST`, not `ZSCORE`/`ZRANGE WITHSCORES`.

```
$ docker exec redis-data-modeling redis-cli TYPE geo:venues:sf
zset
```
`TYPE` reports `zset`, confirming that `GEOADD` doesn't create a distinct "geo" type — it's `ZADD` under the hood, with the member's score computed from its longitude/latitude via geohash encoding. That's also why every geo command (`GEOSEARCH`, `GEODIST`, etc.) is really a specialized way of reading a sorted set whose scores happen to encode 2D position.
