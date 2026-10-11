# Solution 04 — HyperLogLog

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt200:visitors:2026-11-01 v1 v2 v3 v4 v5 v6
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt200:visitors:2026-11-01
(integer) 6
```

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt200:visitors:2026-11-01 v2 v3 v7
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt200:visitors:2026-11-01
(integer) 7
```
Only `v7` is new (`v2`/`v3` were already counted), so the count goes from 6 to 7 — matches expectation exactly at this small scale.

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt200:visitors:2026-11-02 v4 v5 v8 v9
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt200:visitors:2026-11-02
(integer) 4
```

```
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt200:visitors:2026-11-01 hll:event:evt200:visitors:2026-11-02
(integer) 9
```
Day 1 has 7 distinct visitors (`v1 v2 v3 v4 v5 v6 v7`), day 2 has 4 (`v4 v5 v8 v9`); the overlap is `v4` and `v5`, so the true union is `7 + 4 - 2 = 9` — which is exactly what the single multi-key `PFCOUNT` estimated, with no third key created.

```
$ docker exec redis-data-modeling redis-cli PFMERGE hll:event:evt200:visitors:total hll:event:evt200:visitors:2026-11-01 hll:event:evt200:visitors:2026-11-02
OK
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt200:visitors:total
(integer) 9
```
Matches the multi-key estimate from the previous task, as expected — `PFMERGE` persists the same union `PFCOUNT` can compute on the fly, so you can keep querying it later without re-specifying every daily key.

```
$ docker exec redis-data-modeling redis-cli STRLEN hll:event:evt200:visitors:total
(integer) 45
```
45 bytes. A `SET` storing 50,000 attendee ids (even short ones, say 8 bytes each) would cost on the order of several hundred KB to a few MB once per-member overhead (pointers, hash table buckets) is counted — HyperLogLog's size doesn't grow with the number of elements added, only with how much precision it needs to keep, which is why it stays in the tens-of-bytes-to-12KB range whether you've added 9 visitors or 9 million.
