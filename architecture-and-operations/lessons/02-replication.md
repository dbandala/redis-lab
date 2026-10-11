# Lesson 02 — Replication: Primary/Replica Topology & Manual Failover

## Learning Objectives

By the end of this lesson you can:
- Stand up a primary with two replicas and read `INFO replication` to confirm the link is healthy on both sides
- Explain why replicas are read-only by default, and when `WAIT` is the right tool for "did my write actually make it out"
- Manually promote a replica with `REPLICAOF NO ONE` and understand exactly what Sentinel (Lesson 03) automates away

## Concept

This lesson switches labs: `cd architecture-and-operations && docker compose -f compose/replication.yml up -d` brings up **three** Redis 8.10.1 containers on their own Docker network — `redis-repl-primary` plus `redis-repl-replica-1`/`redis-repl-replica-2` — instead of the single-node stack every earlier lesson used. Stop the base stack first if it's still running (`docker compose down`), since this is a different topology, not an extra service bolted onto the same one.

Each replica is started with `--replicaof redis-repl-primary 6379` in its `command:`. That's **the container's internal port**, always `6379` — never the host-mapped port (`6380` for the primary) you'd use from your own terminal. This trips people up constantly: replicas talk to each other over the Docker network's internal DNS and internal ports, completely independent of whatever ports Compose happens to publish to your host for `redis-cli` convenience.

```
$ docker exec redis-repl-primary redis-cli INFO replication
role:master
connected_slaves:2
slave0:ip=172.21.0.3,port=6379,state=online,offset=8260,lag=0,io-thread=0
slave1:ip=172.21.0.4,port=6379,state=online,offset=8260,lag=0,io-thread=0
...
```

```
$ docker exec redis-repl-replica-1 redis-cli INFO replication
role:slave
master_host:redis-repl-primary
master_port:6379
master_link_status:up
master_last_io_seconds_ago:9
slave_repl_offset:8260
...
```

Two fields to know by heart for on-call: `master_link_status:up` (the replica thinks it's connected and current) and the matching `offset` numbers on both sides (primary's `master_repl_offset` should equal each replica's `slave_repl_offset` once caught up — a growing gap means replication lag).

Writes go to the primary and show up on replicas asynchronously, almost always within milliseconds on a local network:

```
$ docker exec redis-repl-primary redis-cli SET pulse:event:evt20 "Riverside Food Fair"
OK
$ docker exec redis-repl-replica-1 redis-cli GET pulse:event:evt20
"Riverside Food Fair"
```

Replicas reject writes by default — this is `replica-read-only yes`, and it's the right default: it stops an application from accidentally splitting its writes across two nodes that will silently diverge.

```
$ docker exec redis-repl-replica-1 redis-cli SET pulse:event:evt21 "should fail"
(error) READONLY You can't write against a read only replica.
```

Because replication is asynchronous, a plain `SET` returning `OK` only tells you the **primary** accepted the write — not that any replica has it yet. `WAIT numreplicas timeout` blocks until at least `numreplicas` replicas have acknowledged the write (or the timeout elapses), which is how you get a synchronous-durability guarantee on top of normally-async replication when a specific write needs it (e.g. "don't tell the customer their ticket purchase succeeded until it's replicated"):

```
$ docker exec redis-repl-primary redis-cli SET pulse:event:evt22 "Downtown Art Walk"
OK
$ docker exec redis-repl-primary redis-cli WAIT 2 1000
(integer) 2
```

**Manual failover.** If the primary dies, nothing promotes a replica automatically — that's Sentinel's job, next lesson. Here's what Sentinel does under the hood, by hand:

```
$ docker stop redis-repl-primary
redis-repl-primary

$ docker exec redis-repl-replica-1 redis-cli REPLICAOF NO ONE
OK
$ docker exec redis-repl-replica-1 redis-cli INFO replication | grep -E "role|connected_slaves"
role:master
connected_slaves:0

$ docker exec redis-repl-replica-2 redis-cli REPLICAOF redis-repl-replica-1 6379
OK
$ docker exec redis-repl-replica-2 redis-cli INFO replication | grep -E "role:|master_link_status"
role:slave
master_link_status:up

$ docker exec redis-repl-replica-1 redis-cli SET pulse:event:evt23 "After the failover"
OK
$ docker exec redis-repl-replica-2 redis-cli GET pulse:event:evt23
"After the failover"
```

`REPLICAOF NO ONE` stops a replica from following any master and makes it a primary in place, keeping all the data it already had. The surviving replica then has to be manually re-pointed with `REPLICAOF <new-primary> <port>`. Notice everything that had to happen by hand: detecting the failure, picking which replica to promote, repointing the others, and — eventually — deciding what to do with the old primary when it comes back (it does *not* automatically know it's been demoted; it'll happily keep thinking it's still the primary unless told otherwise). Automating exactly this sequence, correctly and without a human watching, is what Redis Sentinel exists for.

## Official Docs

- [Replication](https://redis.io/docs/latest/operate/oss_and_stack/management/replication/)
- [REPLICAOF](https://redis.io/docs/latest/commands/replicaof/)
- [WAIT](https://redis.io/docs/latest/commands/wait/)
- [INFO](https://redis.io/docs/latest/commands/info/)

## Exercise

→ [exercises/02-replication/exercise.md](../exercises/02-replication/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" covers the replication protocol (full sync vs. partial resync, the replication backlog) in more depth than this lesson does.
