# Lesson 05 — Redis Cluster Operations: Resharding & Multi-Key Limits

## Learning Objectives

By the end of this lesson you can:
- Add a new node to a running cluster and migrate a specific number of slots onto it
- Explain what `MOVED` looks like for a key whose slot just moved, and why a cluster-aware client barely notices
- Remove a node and return a cluster's slot ownership to where it started
- State, concretely, Cluster's hard limit on multi-key operations and why it exists

## Concept

Scaling Cluster out means adding a node and giving it some slots — "resharding." This lesson adds a 7th node to Lesson 04's 6-node cluster **ad hoc** with `docker run` (not baked permanently into `compose/cluster.yml`, since it would otherwise sit idle through every other lesson and the capstone) and walks the full add → migrate → remove cycle. **Do the cleanup at the end of this lesson** — unlike every earlier lesson, skipping it leaves the cluster in a different, stale 7-node shape for whatever you run next.

```
$ docker run -d --name redis-cluster-7 --network redis-lab-cluster-net \
    -p 6406:6379 -v redis-cluster-7-data:/data redis:8.10.1 \
    redis-server --port 6379 --cluster-enabled yes --cluster-config-file nodes.conf \
    --cluster-node-timeout 5000 --appendonly yes --save 60 1

$ docker exec redis-cluster-1 redis-cli --cluster add-node redis-cluster-7:6379 redis-cluster-1:6379
...
[OK] New node added correctly.
```

`add-node <new-node> <existing-node>` joins the new node to the existing cluster as an empty master — `CLUSTER NODES` now shows it with `connected` but **zero slots**. It owns nothing until you explicitly move slots onto it. (To add a *replica* instead, the same command takes `--cluster-slave --cluster-master-id <id>`.)

**Resharding** moves a specific count of slots from one node to another:

```
$ docker exec redis-cluster-1 redis-cli --cluster reshard redis-cluster-1:6379 \
    --cluster-from a10f693488f291805b97b5b83c63da6df2c3b6c1 \
    --cluster-to   3ec33d6c0431313870a08ce2de66046a617c8778 \
    --cluster-slots 1000 --cluster-yes
    Moving slot 999 from a10f693488f291805b97b5b83c63da6df2c3b6c1
Moving 1000 slots from redis-cluster-1:6379 to 172.21.0.9:6379
```

`--cluster-from`/`--cluster-to` take **node IDs** (from `CLUSTER NODES`), not addresses — look them up first. Behind that one command, Redis is actually migrating live data slot-by-slot: for each slot, it marks the slot `MIGRATING` on the source and `IMPORTING` on the destination, moves every key in it, then atomically reassigns ownership — all while the cluster keeps serving other slots' traffic normally.

Once a slot has moved, a client without an up-to-date slot map gets exactly the redirect from Lesson 04, just now pointing somewhere new:

```
$ docker exec redis-cluster-1 redis-cli SET pulse:cap:11 "resharded value"
(error) MOVED 429 172.21.0.9:6379

$ docker exec redis-cluster-1 redis-cli -c SET pulse:cap:11 "resharded value"
OK
```

This is the entire point of `MOVED`-based routing: a resharding operation never requires client downtime or reconfiguration — clients just pay the cost of one redirect per slot they touch for the first time after a move, then cache the new location.

**Cleanup — move the slots back and remove the node:**

```
$ docker exec redis-cluster-1 redis-cli --cluster reshard redis-cluster-1:6379 \
    --cluster-from 3ec33d6c0431313870a08ce2de66046a617c8778 \
    --cluster-to   a10f693488f291805b97b5b83c63da6df2c3b6c1 \
    --cluster-slots 1000 --cluster-yes
```

> **A nuance worth noticing.** Once the reshard-back leaves node 7 with zero slots, `CLUSTER NODES` shows it automatically reclassified as a **replica** of the node it just emptied into — the `--cluster reshard` tool does this on your behalf rather than leaving a slotless, orphaned master sitting around.

```
$ docker exec redis-cluster-1 redis-cli --cluster del-node redis-cluster-1:6379 3ec33d6c0431313870a08ce2de66046a617c8778
>>> Sending CLUSTER FORGET messages to the cluster...
$ docker rm -f redis-cluster-7
$ docker volume rm redis-cluster-7-data
```

`del-node` needs the node to own zero slots first — it refuses to remove a node that's still holding data, which is exactly the guardrail you want against accidentally dropping a shard full of live keys.

**The hard limit, restated precisely.** Cluster never lets you atomically operate on keys spread across multiple nodes — not in `MSET`, not in a `MULTI`/`EXEC` transaction, not in an `EVAL` script. Every multi-key operation requires every key involved to resolve to the same slot (via identical key names or a shared hash tag). This isn't a missing feature to work around — it's the direct consequence of sharding: an atomic operation spanning two independent processes on two different machines would require distributed transaction machinery Cluster deliberately doesn't implement, trading that capability for linear horizontal scalability instead.

## Official Docs

- [Redis Cluster specification — resharding](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/#resharding)
- [redis-cli --cluster help](https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/#create-a-redis-cluster)
- [CLUSTER FORGET](https://redis.io/docs/latest/commands/cluster-forget/)

## Exercise

→ [exercises/05-cluster-operations/exercise.md](../exercises/05-cluster-operations/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU302: Running Redis at Scale" walks through live resharding under production traffic, including how client libraries detect and adapt to slot migrations mid-flight.
