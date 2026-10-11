# Lesson 03 — High Availability with Redis Sentinel

## Learning Objectives

By the end of this lesson you can:
- Explain what Sentinel actually is: a separate monitoring process, not a mode `redis-server` runs in
- Read `SENTINEL ckquorum` and `SENTINEL get-master-addr-by-name` to check a deployment's health and find the current primary
- Watch Sentinel detect a primary failure and automatically perform everything Lesson 02 did by hand
- State why Sentinel's quorum mechanism exists and what it protects against

## Concept

Lesson 02 ended with a list of manual steps a human has to perform to fail over a dead primary. **Sentinel is a separate, purpose-built process** — not a flag on `redis-server` — whose only job is to automate exactly that list: monitor a primary and its replicas, detect failure, agree with other Sentinels that the failure is real, pick a replica, and promote it.

This lesson uses `compose/sentinel.yml`: a primary + 2 replicas (same shape as Lesson 02) plus **three** independent `sentinel-1`/`sentinel-2`/`sentinel-3` processes, each running the exact same config:

```
port 26379
sentinel resolve-hostnames yes
sentinel monitor pulse-primary redis-sentinel-primary 6379 2
sentinel down-after-milliseconds pulse-primary 5000
sentinel failover-timeout pulse-primary 10000
sentinel parallel-syncs pulse-primary 1
```

`sentinel monitor pulse-primary redis-sentinel-primary 6379 2` names the primary (`pulse-primary` — Sentinel's own label, unrelated to any Redis key), where to find it, and the **quorum**: `2`. Quorum is the minimum number of Sentinels that must independently agree the primary is unreachable before any of them is even allowed to *start* a failover vote. With 3 Sentinels and quorum 2, one Sentinel having a bad network day isn't enough to trigger a failover — you need a majority to agree, which is the whole point: it protects against exactly the kind of lone-Sentinel false positive that would otherwise cause an unnecessary, disruptive failover. `sentinel resolve-hostnames yes` is required here — without it, Sentinel refuses to start when `sentinel monitor` names a hostname (`redis-sentinel-primary`) instead of a bare IP, which is exactly how every node in a Docker Compose network is addressed.

> **Lab-speed tuning, not a Redis default.** Production Sentinel defaults are `down-after-milliseconds 30000` / `failover-timeout 180000` — 30s to declare a primary down, up to 3 minutes for the failover itself. This lab tunes both down to `5000`/`10000` so a failover demo doesn't mean sitting idle for minutes. Don't carry these numbers into production unexamined; they're a classroom convenience, not a recommendation.

Once the stack is up, any Sentinel can answer who's currently in charge and whether the deployment is healthy enough to act if needed:

```
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL ckquorum pulse-primary
OK 3 usable Sentinels. Quorum and failover authorization can be reached
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name pulse-primary
172.21.0.2
6379
```

Now kill the primary and watch, without touching anything else:

```
$ docker stop redis-sentinel-primary
redis-sentinel-primary

$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name pulse-primary
172.21.0.2     # still the old (now-dead) address — Sentinel hasn't declared it down yet
6379

... a few seconds later ...

$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name pulse-primary
172.21.0.4     # a different IP: Sentinel promoted a replica
6379
```

In this lab's tuned-down config, that transition happened **6 seconds** after the `docker stop` — Sentinel detected the missing primary, had the other two Sentinels agree it was really down, picked `redis-sentinel-replica-2` (confirmed with `INFO replication` → `role:master`), ran `REPLICAOF NO ONE` on it, and reconfigured `redis-sentinel-replica-1` to follow the new primary — the entire sequence from Lesson 02, done without a human. Bring the old primary back and Sentinel reconciles it too:

```
$ docker start redis-sentinel-primary
redis-sentinel-primary

... ~10 seconds later ...

$ docker exec redis-sentinel-primary redis-cli INFO replication | grep role
role:slave
```

The old primary comes back, Sentinel notices it, and demotes it to a replica of the new primary automatically — it never silently stays a rogue, disconnected "primary" believing nothing changed.

**What applications actually connect to.** Your application shouldn't hardcode a primary's address — it asks Sentinel for the current one (`SENTINEL get-master-addr-by-name`), which is exactly what every mainstream Redis client library's "Sentinel mode" does under the hood: connect to the configured Sentinel addresses first, ask for the current primary, then connect there, retrying the lookup if a write ever fails.

## Official Docs

- [High availability with Redis Sentinel](https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/)
- [SENTINEL commands](https://redis.io/docs/latest/commands/?name=sentinel)

## Exercise

→ [exercises/03-sentinel-and-high-availability/exercise.md](../exercises/03-sentinel-and-high-availability/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" includes a Sentinel module covering split-brain scenarios and multi-datacenter quorum sizing beyond what this single-host lab can demonstrate.
