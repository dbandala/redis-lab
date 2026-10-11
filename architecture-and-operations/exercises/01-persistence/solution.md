# Solution 01 — Persistence

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET save
1) "save"
2) "60 1"
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET appendonly
1) "appendonly"
2) "yes"
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET appendfsync
1) "appendfsync"
2) "everysec"
```
This lab runs with both mechanisms on: RDB snapshots every 60s if at least 1 key changed, plus AOF fsync'd once per second.

```
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt10 "Night Lights Festival"
OK
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt11 "Sunset Jazz Night"
OK
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt12 "Harbor Comedy Hour"
OK
```

```
$ docker exec redis-architecture-and-operations redis-cli SAVE
OK
$ docker exec redis-architecture-and-operations redis-cli LASTSAVE
(integer) 1791664953
$ docker exec redis-architecture-and-operations ls -la /data
drwxr-xr-x 3 redis redis 4096 appendonlydir
-rw------- 1 redis redis  286 dump.rdb
```
`SAVE` produced `dump.rdb` — a full point-in-time snapshot of the keyspace, written synchronously (the server blocked until it finished, which is why production code paths use `BGSAVE` instead).

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET appendfsync always
OK
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET appendfsync
1) "appendfsync"
2) "always"
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET appendfsync everysec
OK
```
Leaving `appendfsync always` on a high-throughput workload trades write latency/throughput for zero-data-loss durability — every single command now waits on a disk `fsync` before the client gets its `OK`, which on typical cloud block storage can be an order of magnitude slower than the in-memory command itself.

```
$ docker exec redis-architecture-and-operations redis-cli BGREWRITEAOF
Background append only file rewriting started
$ docker exec redis-architecture-and-operations ls -la /data/appendonlydir
-rw------- 1 redis redis  286 appendonly.aof.3.base.rdb
-rw------- 1 redis redis    0 appendonly.aof.3.incr.aof
-rw------- 1 redis redis  102 appendonly.aof.manifest
```
Three files, Redis 7+'s multi-part AOF: `*.base.rdb` is an RDB-formatted snapshot of the keyspace at rewrite time (the new baseline); `*.incr.aof` is the incremental log of commands appended *since* that base — empty here because nothing was written after the rewrite; `manifest` is a small text index listing which base + incr files make up the current AOF and in what order, so Redis knows what to replay on startup without guessing from filenames.

**Step 6:** Redis loses only **~1 second**, not ~60. On restart, if both RDB and AOF are present, Redis loads from **AOF**, not the RDB file — the `save 60 1` snapshot interval governs how current the RDB *backup* is, but it isn't in the crash-recovery path when AOF is enabled. AOF's `everysec` fsync means at most the last second of acknowledged writes before the crash were sitting unflushed in the OS page cache; everything before that was already durably on disk and gets replayed from the incremental AOF file on top of the base. This is exactly why the two mechanisms are complementary rather than redundant: RDB is for compact backups/restore speed, AOF is for recovery granularity.
