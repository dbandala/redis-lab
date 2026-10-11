# Solution 10 — Commands and Complexity

```
$ ./seed-biglist.sh
Seeded biglist:demo with 5000 elements
$ docker exec redis-foundations redis-cli LLEN biglist:demo
(integer) 5000
```

```
$ time docker exec redis-foundations redis-cli -r 1000 LRANGE biglist:demo 0 -1 > /dev/null
2.07s total (≈ 2.07 ms/call)

$ time docker exec redis-foundations redis-cli -r 1000 LRANGE biglist:demo 0 9 > /dev/null
0.28s total (≈ 0.28 ms/call)
```
The full-range read is roughly **7× slower per call** than the bounded 10-element read of the same list — real, measured evidence of `LRANGE`'s O(N) behavior (`-r 1000` repeats the command 1000 times over one held-open connection, so the comparison isolates command cost rather than per-process startup overhead). Numbers will vary run to run and machine to machine, but the full-range call should consistently be several times slower.

```
$ docker exec redis-foundations redis-cli OBJECT ENCODING biglist:demo
"quicklist"
```
At 5,000 elements the list has been promoted past `listpack` (default threshold 128 entries) to `quicklist` — a linked list of listpack nodes, built specifically to handle lists too large for one contiguous block.

4. Time complexity table (from the official docs, `redis.io/docs/latest/commands/<name>/`):

| Command | Time complexity |
|---|---|
| `GET` | O(1) |
| `SET` | O(1) |
| `HGET` | O(1) |
| `HGETALL` | O(N) — N = number of fields in the hash |
| `SADD` | O(1) per element added |
| `SMEMBERS` | O(N) — N = set cardinality |
| `ZADD` | O(log N) per element added — N = sorted set size |
| `ZRANK` | O(log N) |
| `LRANGE` | O(S+N) — S = offset to the start, N = number of elements returned; O(N) for a full-range read |
| `KEYS` | O(N) — N = total number of keys in the database |
