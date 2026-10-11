# Lesson 04 — Redis Cluster Fundamentals: Hash Slots & Topology

## Learning Objectives

By the end of this lesson you can:
- Explain what problem Redis Cluster solves that replication + Sentinel don't (write throughput beyond one primary's capacity, dataset bigger than one node's RAM)
- Bootstrap a 6-node cluster (3 primaries + 3 replicas) and read `CLUSTER INFO`/`CLUSTER NODES`
- Explain hash slots, predict `CROSSSLOT` errors, and use hash tags to co-locate related keys in the same slot
- State the single biggest Docker-specific gotcha in running Redis Cluster locally

## Concept

Sentinel (Lesson 03) solves *availability* — one primary stays reachable even if a node dies. It does nothing for *capacity*: every write still goes through a single primary's single CPU core and however much RAM that one box has. **Redis Cluster** solves that by **sharding** the keyspace across multiple primaries, each owning a slice of it, with Sentinel-style failover built in per-shard (each primary has its own replica(s), promoted automatically on failure — no separate Sentinel process needed).

This lesson uses `compose/cluster.yml`: six plain-looking Redis nodes (`redis-cluster-1` .. `redis-cluster-6`), each started with `--cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000` — that's it. Cluster mode doesn't require a different image, just these flags. Nothing is actually *clustered* yet, though — each node still thinks it's alone until you tell them about each other:

```
$ docker exec redis-cluster-1 redis-cli --cluster create \
    redis-cluster-1:6379 redis-cluster-2:6379 redis-cluster-3:6379 \
    redis-cluster-4:6379 redis-cluster-5:6379 redis-cluster-6:6379 \
    --cluster-replicas 1 --cluster-yes
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica redis-cluster-5:6379 to redis-cluster-1:6379
Adding replica redis-cluster-6:6379 to redis-cluster-2:6379
Adding replica redis-cluster-4:6379 to redis-cluster-3:6379
...
[OK] All nodes agree about slots configuration.
[OK] All 16384 slots covered.
```

> **The single biggest Docker-specific gotcha with Redis Cluster.** Run this bootstrap command **from inside a node container** (`docker exec`), never from the host against the published ports. Cluster nodes gossip the IP address they *see* a `CLUSTER MEET` arrive from — run `--cluster create` from the host against `localhost:6400` etc. and nodes end up trying to gossip NAT'd, host-side addresses to each other over `CLUSTER MEET`, which breaks. Running from inside a container on the cluster's own Docker network means container-name DNS resolves to real, routable container IPs, and that's what gets gossiped correctly. For the same reason: every cluster-aware command in this lesson and its exercise is written as `docker exec redis-cluster-N redis-cli -c ...` — a host-installed `redis-cli` against the mapped ports can't follow cluster redirects to container IPs it can't reach.

`--cluster-replicas 1` means every primary gets exactly one replica; `--cluster-yes` skips the interactive confirmation prompt so this is scriptable. The result: **3 primaries, 3 replicas**, confirmed with:

```
$ docker exec redis-cluster-1 redis-cli CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
...
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES
c55e673... 172.21.0.6:6379@16379 master - ... connected 5461-10922
a10f693... 172.21.0.3:6379@16379 myself,master - ... connected 0-5460
0bcc681... 172.21.0.8:6379@16379 master - ... connected 10923-16383
f2f382a... 172.21.0.5:6379@16379 slave a10f693... ... connected
df39b4a... 172.21.0.7:6379@16379 slave 0bcc681... ... connected
78758c2... 172.21.0.2:6379@16379 slave c55e673... ... connected
```

`CLUSTER NODES` reports each node by its **Docker-internal IP**, not its service name — don't expect to see `redis-cluster-2` in that output, you'll see `172.21.0.6` instead.

**Hash slots.** The entire keyspace is divided into **16384 fixed slots**. Every key is deterministically mapped to exactly one slot via `CRC16(key) % 16384`, and each primary owns a contiguous range of slots (here: 0-5460, 5461-10922, 10923-16383). This is why Cluster can route any single-key command without asking anyone — the client (or `redis-cli -c`) computes the slot, consults its cached slot map, and either goes straight to the right node or follows a `MOVED` redirect if its map is stale:

```
$ docker exec redis-cluster-1 redis-cli -c SET foo bar
OK
$ docker exec redis-cluster-1 redis-cli -c GET foo
"bar"
$ docker exec redis-cluster-1 redis-cli CLUSTER KEYSLOT foo
(integer) 12182
```
`-c` (cluster mode) made `redis-cli` quietly follow the redirect to whichever node owns slot 12182 — you never saw it happen. Without `-c`, you see the raw protocol-level answer instead:
```
$ docker exec redis-cluster-1 redis-cli SET zzzzzzzzzzzzzzzzzzzzz val
(error) MOVED 7310 172.21.0.6:6379
```
`MOVED <slot> <ip:port>` is Cluster telling a client "you asked the wrong node; slot 7310 lives at that address — go there, and update your slot map." A smart client library caches the slot map and avoids most redirects after the first one per slot range; it only resyncs on a `MOVED`/`ASK` it didn't expect (e.g. after a resharding, covered next lesson).

**Multi-key operations are constrained to one slot.** `MSET`, transactions, and Lua scripts touching multiple keys all require every key involved to hash to the *same* slot — Cluster has no cross-node multi-key atomicity story:

```
$ docker exec redis-cluster-1 redis-cli -c MSET foo bar baz qux
(error) CROSSSLOT Keys in request don't hash to the same slot
```

**Hash tags** solve this: wrap the part of the key you want hashed in `{curly braces}`, and Cluster hashes *only* that substring, letting you deliberately co-locate related keys in the same slot:

```
$ docker exec redis-cluster-1 redis-cli -c MSET '{user1}:name' bob '{user1}:email' bob@x.com
OK
```
`{user1}:name` and `{user1}:email` both hash on `user1` alone, land in the same slot, and can now be read, written, or scripted together atomically. This is the same technique you'd reach for to keep, say, a Pulse user's profile hash and their session set co-located if you ever sharded Pulse's Level 2 data model across a cluster.

## Official Docs

- [Scale with Redis Cluster](https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/)
- [Redis Cluster specification](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/)
- [CLUSTER KEYSLOT](https://redis.io/docs/latest/commands/cluster-keyslot/)
- [Hash tags](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/#hash-tags)

## Exercise

→ [exercises/04-cluster-fundamentals/exercise.md](../exercises/04-cluster-fundamentals/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU302: Running Redis at Scale" is entirely dedicated to Cluster: slot migration internals, client-side routing, and multi-key design patterns beyond this lesson's scope.
