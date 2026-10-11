# Lesson 01 — Persistence: RDB Snapshots vs AOF

## Learning Objectives

By the end of this lesson you can:
- Explain what RDB snapshots and the Append Only File (AOF) each actually persist, and why Redis offers both instead of just one
- Trigger and inspect both mechanisms (`SAVE`/`BGSAVE`, `BGREWRITEAOF`) and read the `/data` directory they produce
- Tune the durability-vs-performance trade-off with `appendfsync`, and explain why `everysec` is the default middle ground
- Recognize Redis 7+'s **multi-part AOF** (a directory, not a single file) when you see it on disk

## Concept

Level 2 built Pulse's hot-data layer — sessions, rate-limit counters, leaderboards — entirely in memory. That's fast, but a container restart or host reboot with no persistence configured means every session token, every ticket-sale counter, every leaderboard standing is gone. Redis gives you two independent, combinable mechanisms to avoid that, and production systems need to understand both well enough to choose deliberately rather than accept the defaults blindly.

**RDB** is a point-in-time binary snapshot of the whole keyspace, written by a forked child process so the main event loop keeps serving traffic:

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET save
1) "save"
2) "60 1"
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-architecture-and-operations redis-cli SAVE
OK
$ docker exec redis-architecture-and-operations redis-cli LASTSAVE
(integer) 1791661902
```

`save 60 1` (this lab's compose command) means "snapshot automatically if at least 1 key changed in the last 60 seconds" — Redis supports multiple such rules stacked together; the default `redis.conf` ships three (`900 1`, `300 10`, `60 10000`). `SAVE` blocks the whole server until the snapshot finishes — never run it on a busy production primary. `BGSAVE` is the one you actually want: it forks and saves in the background while the parent keeps answering requests.

```
$ docker exec redis-architecture-and-operations redis-cli BGSAVE
Background saving started
$ docker exec redis-architecture-and-operations redis-cli INFO persistence | grep -E "rdb_bgsave_in_progress|rdb_last_bgsave_status"
rdb_bgsave_in_progress:0
rdb_last_bgsave_status:ok
```

`rdb_last_bgsave_status:ok` is the field to alert on in production — `err` means your last snapshot silently failed (usually disk space or permissions). The result lands as one file:

```
$ docker exec redis-architecture-and-operations ls -la /data
-rw------- 1 redis redis  170 dump.rdb
drwx------ 2 redis redis 4096 appendonlydir
```

RDB's weakness: anything written *since* the last snapshot is lost on a crash — with `save 60 1`, up to a minute of writes. That's where **AOF** comes in: instead of a periodic snapshot, Redis appends every write command to a log as it happens, and replays the log on startup.

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET appendonly
1) "appendonly"
2) "yes"
$ docker exec redis-architecture-and-operations redis-cli CONFIG GET appendfsync
1) "appendfsync"
2) "everysec"
```

> **What's new: AOF is a directory, not a file.** Through Redis 6, `appendonly yes` wrote one ever-growing `appendonly.aof` file, periodically rewritten in full. Since **Redis 7**, AOF is multi-part: a `appendonlydir/` holding one base file (an RDB-formatted snapshot — `BGREWRITEAOF`'s output), one or more incremental files (the actual appended commands since that base), and a manifest tying them together. This is why `BGREWRITEAOF` is fast and nearly I/O-free compared to the old full-file rewrite: it only needs to write a new base file and start a fresh, empty incremental file, not replay history into one giant file.

```
$ docker exec redis-architecture-and-operations ls -la /data/appendonlydir
-rw------- 1 redis redis  170 appendonly.aof.2.base.rdb
-rw------- 1 redis redis    0 appendonly.aof.2.incr.aof
-rw------- 1 redis redis  102 appendonly.aof.manifest
$ docker exec redis-architecture-and-operations redis-cli BGREWRITEAOF
Background append only file rewriting started
$ docker exec redis-architecture-and-operations redis-cli INFO persistence | grep -E "aof_rewrite_in_progress|aof_last_bgrewrite_status"
aof_rewrite_in_progress:0
aof_last_bgrewrite_status:ok
```

**`appendfsync` is the real durability-vs-performance dial.** It controls how often the AOF's incremental file is flushed from the OS page cache to disk with `fsync`:

| `appendfsync` | Durability | Performance | When to use |
|---|---|---|---|
| `always` | Every write fsync'd before the client gets `OK` | Slowest — an fsync is a disk round-trip per command | Financial/audit workloads where losing *any* acknowledged write is unacceptable |
| `everysec` (default) | fsync once per second in a background thread | Near-memory-speed writes; worst case loses ~1s of data on a crash | The right default for almost everything, including Pulse |
| `no` | OS decides when to flush (can be minutes under load) | Fastest | Rarely justified — you're trusting the kernel's own flush timing with your durability guarantee |

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET appendfsync always
OK
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET appendfsync everysec
OK
```

**In production, run both.** RDB snapshots are what you ship to backup storage (compact, fast to restore, ideal for disaster recovery and spinning up new replicas); AOF is what gives you sub-second recovery granularity on a crash. On restart with both enabled, Redis loads from AOF (the more current source), not the RDB file. Pick `noeviction`-grade durability (`everysec` + a `save` rule that matches how much data loss Pulse can tolerate) deliberately — don't just leave the image defaults unexamined, because the right answer genuinely differs between a session cache (losing a few seconds is fine) and a ticket-sale ledger (it usually isn't, which is why Level 5 revisits this boundary when deciding what belongs in Redis at all vs. a durable system of record).

## Official Docs

- [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [SAVE](https://redis.io/docs/latest/commands/save/)
- [BGSAVE](https://redis.io/docs/latest/commands/bgsave/)
- [BGREWRITEAOF](https://redis.io/docs/latest/commands/bgrewriteaof/)
- [CONFIG SET](https://redis.io/docs/latest/commands/config-set/)

## Exercise

→ [exercises/01-persistence/exercise.md](../exercises/01-persistence/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Developers" covers persistence fundamentals; the "RedisInsight" lessons there show snapshot/AOF status in the GUI if you prefer not to parse `INFO persistence` by hand.
