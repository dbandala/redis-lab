# Solution 09 — SCAN vs KEYS

```
$ ./seed-keys.sh
Seeded 50 keys under demo:key:*
$ docker exec redis-foundations redis-cli DBSIZE
(integer) 65
```
(65 total — 50 fresh `demo:*` keys plus whatever keys survived from earlier lessons in this same lab environment.)

```
$ docker exec redis-foundations redis-cli KEYS "demo:*" | wc -l
50
```
Safe here because the whole keyspace is tiny (a handful of keys), so the single blocking scan `KEYS` performs takes microseconds. Against a production database with millions of keys, that same single call would block the entire single-threaded server for the whole scan — every other client's commands (including health checks) would queue up behind it, potentially for seconds, causing a self-inflicted outage.

```
$ docker exec redis-foundations redis-cli SCAN 0 MATCH "demo:*" COUNT 10
68
1) "demo:key:41"
2) "demo:key:11"
3) "demo:key:8"
4) "demo:key:15"
5) "demo:key:13"
6) "demo:key:6"
7) "demo:key:50"

$ docker exec redis-foundations redis-cli SCAN 68 MATCH "demo:*" COUNT 10
124
...(9 more keys)...
```
Continuing to feed each returned cursor back in, this particular run took **7 round trips** before getting cursor `0` back (cursors observed: `68 → 124 → 14 → 53 → 19 → 119 → 0`), having returned all 50 `demo:*` keys across those batches. Your exact cursor sequence and batch sizes will differ — `COUNT` is only a hint, and cursor values depend on Redis's internal hash table layout — but you should also land on all 50 keys and terminate at cursor `0`.

```
$ docker exec redis-foundations redis-cli HSCAN user:1001 0
0
1) "name"
2) "Ada"
3) "login_count"
4) "1"

$ docker exec redis-foundations redis-cli SSCAN article:42:tags 0
0
1) "redis"
2) "database"
3) "nosql"
```
Both return cursor `0` immediately — these structures are small enough to fit in one batch.
