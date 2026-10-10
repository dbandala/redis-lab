# Lesson 06 — Geospatial Indexes

## Learning Objectives

By the end of this lesson you can:
- Index points with `GEOADD` and query them with `GEOSEARCH` (`BYRADIUS`/`BYBOX`, `FROMMEMBER`/`FROMLONLAT`)
- Persist a search result with `GEOSEARCHSTORE`
- Know to use `GEOSEARCH` instead of the deprecated `GEORADIUS`/`GEORADIUSBYMEMBER`, and explain why a geo index is really a sorted set

## Concept

Pulse needs "find venues near this point" — a classic geospatial query. Redis's geo commands store longitude/latitude pairs as **geohash-encoded scores in a sorted set**: `GEOADD` is really `ZADD` with the score computed from the coordinates, which is why `TYPE` on a geo key reports `zset`, not some new "geo" type.

```
$ docker exec redis-data-modeling redis-cli GEOADD geo:venues -122.4194 37.7749 "venue:moscone" -122.4015 37.7835 "venue:chase-center" -122.2585 37.8044 "venue:oracle-arena"
(integer) 3
$ docker exec redis-data-modeling redis-cli GEOPOS geo:venues venue:moscone
1) 1) "-122.41940170526505"
   2) "37.77490001056578"
$ docker exec redis-data-modeling redis-cli GEODIST geo:venues venue:moscone venue:chase-center km
"1.8416"
$ docker exec redis-data-modeling redis-cli TYPE geo:venues
zset
```

`GEOPOS` returns coordinates with floating-point rounding from the geohash encoding — expect tiny precision loss (fractions of a meter), not an exact round-trip of what you put in. `GEODIST` computes great-circle distance between two members directly, no client-side math needed.

> **Deprecated: don't use `GEORADIUS` / `GEORADIUSBYMEMBER`.** They still work for backward compatibility, but `GEOSEARCH` (Redis 6.2+) replaced them with one command that covers both "search from a point" and "search from an existing member," plus a box option `GEORADIUS` never had. Write new code against `GEOSEARCH`/`GEOSEARCHSTORE` only.

```
$ docker exec redis-data-modeling redis-cli GEOSEARCH geo:venues FROMLONLAT -122.41 37.78 BYRADIUS 5 km ASC WITHDIST WITHCOORD
1) 1) "venue:chase-center"
   2) "0.8425"
   3) 1) "-122.40150064229965"
      2) "37.78350031945942"
2) 1) "venue:moscone"
   2) "1.0025"
   3) 1) "-122.41940170526505"
      2) "37.77490001056578"
$ docker exec redis-data-modeling redis-cli GEOSEARCH geo:venues FROMMEMBER venue:moscone BYBOX 10 10 km ASC WITHDIST
1) 1) "venue:moscone"
   2) "0.0000"
2) 1) "venue:chase-center"
   2) "1.8416"
```

`FROMLONLAT`/`FROMMEMBER` pick the search origin (an arbitrary point, or an existing indexed member); `BYRADIUS`/`BYBOX` pick the search shape (a circle, or a width×height box); `ASC` sorts nearest-first; `WITHDIST`/`WITHCOORD` attach the computed distance and/or coordinates to each result. Note `venue:oracle-arena` — about 15km away across the bay — shows up in neither query, since it's outside both the 5km radius and the 10x10km box.

`GEOSEARCHSTORE` persists a search result as its own sorted set, same idea as `ZRANGESTORE` from Lesson 02:

```
$ docker exec redis-data-modeling redis-cli GEOSEARCHSTORE geo:venues:nearby geo:venues FROMLONLAT -122.41 37.78 BYRADIUS 5 km ASC
(integer) 2
$ docker exec redis-data-modeling redis-cli ZRANGE geo:venues:nearby 0 -1 WITHSCORES
1) "venue:moscone"
2) "1367859919124626"
3) "venue:chase-center"
4) "1367859963013657"
```

Reading the stored result back with plain `ZRANGE` confirms it — the scores are the raw 52-bit geohash integers, not distances; that's the one place the "it's just a sorted set" abstraction leaks through, so always read geo data back with `GEOPOS`/`GEODIST`/`GEOSEARCH`, not `ZSCORE`.

## Official Docs

- [GEOADD](https://redis.io/docs/latest/commands/geoadd/)
- [GEOSEARCH](https://redis.io/docs/latest/commands/geosearch/)
- [GEOSEARCHSTORE](https://redis.io/docs/latest/commands/geosearchstore/)
- [GEODIST](https://redis.io/docs/latest/commands/geodist/)

## Exercise

→ [exercises/06-geospatial/exercise.md](../exercises/06-geospatial/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — geospatial indexing is covered as a worked example in "RU101: Introduction to Redis Data Structures."
