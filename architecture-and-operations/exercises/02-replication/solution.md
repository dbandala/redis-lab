# Solution 02 — Replication

```
$ docker exec redis-repl-primary redis-cli INFO replication | grep connected_slaves
connected_slaves:2
$ docker exec redis-repl-replica-1 redis-cli INFO replication | grep -E "role:|master_link_status"
role:slave
master_link_status:up
$ docker exec redis-repl-replica-2 redis-cli INFO replication | grep -E "role:|master_link_status"
role:slave
master_link_status:up
```
Both replicas report `up`, and the primary counts exactly 2 connected slaves — the topology is healthy.

```
$ docker exec redis-repl-primary redis-cli SET pulse:event:evt30 "Lakeside Film Screening"
OK
$ docker exec redis-repl-replica-1 redis-cli GET pulse:event:evt30
"Lakeside Film Screening"
$ docker exec redis-repl-replica-2 redis-cli GET pulse:event:evt30
"Lakeside Film Screening"
```
Both replicas had the value essentially instantly — on a local Docker network, replication lag is sub-millisecond; it only becomes visible under real network latency or a replica falling behind under load.

```
$ docker exec redis-repl-replica-2 redis-cli SET pulse:event:evt99 nope
(error) READONLY You can't write against a read only replica.
```
Controlled by `replica-read-only` (`yes` by default). It exists to stop an application bug from writing to the wrong node and quietly forking the dataset in two.

```
$ docker exec redis-repl-primary redis-cli SET pulse:event:evt31 "Midtown Night Market"
OK
$ docker exec redis-repl-primary redis-cli WAIT 2 1000
(integer) 2
```
`2` means both replicas acknowledged the write within the 1000ms timeout — this specific write is now known to exist on 3 nodes, not just the primary's memory. Had it returned `1`, it would mean only one replica had caught up within the timeout window (the other was slower, or momentarily disconnected) — the write still succeeded on the primary either way; `WAIT`'s return value only tells you how widely it's already propagated, it never un-does the write if replicas don't catch up in time.

```
$ docker stop redis-repl-primary
redis-repl-primary
$ docker exec redis-repl-replica-1 redis-cli REPLICAOF NO ONE
OK
$ docker exec redis-repl-replica-2 redis-cli REPLICAOF redis-repl-replica-1 6379
OK
$ docker exec redis-repl-replica-1 redis-cli SET pulse:event:evt32 "Promoted and writable"
OK
$ docker exec redis-repl-replica-2 redis-cli GET pulse:event:evt32
"Promoted and writable"
```
`redis-repl-replica-1` is now a primary in its own right, still holding all the data it replicated before the failure, and `redis-repl-replica-2` is following it.

**Step 6:** The manual steps were: (a) *notice* the primary was down in the first place, (b) *decide* which replica to promote (if there'd been a real split-brain risk or unequal replication offsets between replica-1 and replica-2, that choice matters and is easy to get wrong under pressure), (c) run `REPLICAOF NO ONE` on the chosen replica, (d) re-point every *other* replica at the new primary, and (e) — not exercised here, but real — decide what to do with the old primary when it eventually comes back online, since it has no idea it's been demoted and will keep claiming to be the primary until told otherwise. A human is almost always too slow at step (a) and too error-prone at step (b) during a real incident — that's precisely the detection-and-decision logic Sentinel automates in the next lesson: it continuously monitors the primary, has multiple independent Sentinel processes agree ("quorum") that it's actually down before acting (avoiding a false positive from one Sentinel's own network blip), and runs steps (c) and (d) itself, every time, the same way.
