# Solution 05 — Redis Cluster Operations

```
$ docker run -d --name redis-cluster-8 --network redis-lab-cluster-net \
    -p 6407:6379 -v redis-cluster-8-data:/data redis:8.10.1 \
    redis-server --port 6379 --cluster-enabled yes --cluster-config-file nodes.conf \
    --cluster-node-timeout 5000 --appendonly yes --save 60 1
$ docker exec redis-cluster-1 redis-cli --cluster add-node redis-cluster-8:6379 redis-cluster-2:6379
[OK] New node added correctly.
```

```
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES
1bd0c1d... 172.21.0.9:6379@16379 master - ... connected               # new node, 0 slots
c55e673... 172.21.0.6:6379@16379 master - ... connected 5461-10922    # redis-cluster-2
a10f693... 172.21.0.3:6379@16379 myself,master - ... connected 0-5460
0bcc681... 172.21.0.8:6379@16379 master - ... connected 10923-16383
...
$ docker exec redis-cluster-1 redis-cli --cluster reshard redis-cluster-1:6379 \
    --cluster-from c55e67379e7d25ae096c6fa5ae786f5bf3432278 \
    --cluster-to   1bd0c1dbec89a1dec5eaa75b2a26da4d61230f6b \
    --cluster-slots 500 --cluster-yes
Moving 500 slots from 172.21.0.6:6379 to 172.21.0.9:6379
```

```
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES | grep master
1bd0c1d... 172.21.0.9:6379@16379 master - ... connected 5461-5960
c55e673... 172.21.0.6:6379@16379 master - ... connected 5961-10922
a10f693... 172.21.0.3:6379@16379 myself,master - ... connected 0-5460
0bcc681... 172.21.0.8:6379@16379 master - ... connected 10923-16383
```
`redis-cluster-2` kept `5961-10922`; the new node took `5461-5960` — exactly 500 slots off the low end of what `redis-cluster-2` used to own.

```
$ docker exec redis-cluster-1 redis-cli CLUSTER KEYSLOT pulse:session:63
(integer) 5582
$ docker exec redis-cluster-1 redis-cli SET pulse:session:63 "abc123"
(error) MOVED 5582 172.21.0.9:6379
$ docker exec redis-cluster-1 redis-cli -c SET pulse:session:63 "abc123"
OK
$ docker exec redis-cluster-1 redis-cli -c GET pulse:session:63
"abc123"
```
`5582` falls inside the new node's `5461-5960` range, which is why the non-`-c` call got redirected — `-c` just followed it silently.

```
$ docker exec redis-cluster-1 redis-cli --cluster reshard redis-cluster-1:6379 \
    --cluster-from 1bd0c1dbec89a1dec5eaa75b2a26da4d61230f6b \
    --cluster-to   c55e67379e7d25ae096c6fa5ae786f5bf3432278 \
    --cluster-slots 500 --cluster-yes
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES
1bd0c1d... 172.21.0.9:6379@16379 slave c55e67379e7d25ae096c6fa5ae786f5bf3432278 ... connected
c55e673... 172.21.0.6:6379@16379 master - ... connected 5461-10922
...
```
With zero slots left, `--cluster reshard` automatically turned the new node into a **replica** of `redis-cluster-2` (the node it just handed everything back to) rather than leaving it a stranded, empty master.

```
$ docker exec redis-cluster-1 redis-cli --cluster del-node redis-cluster-1:6379 1bd0c1dbec89a1dec5eaa75b2a26da4d61230f6b
>>> Sending CLUSTER FORGET messages to the cluster...
$ docker rm -f redis-cluster-8
$ docker volume rm redis-cluster-8-data
```

```
$ docker exec redis-cluster-1 redis-cli CLUSTER INFO | head -3
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES | wc -l
6
```
Back to exactly 6 nodes, all 16384 slots covered — the same shape Lesson 04 ended in.

**Step 9:** `--cluster del-node` on a node that still owns slots refuses outright:
```
$ docker exec redis-cluster-1 redis-cli --cluster del-node redis-cluster-1:6379 <node-still-holding-slots>
[ERR] Node 172.21.0.9:6379 is not empty! Reshard data away and try again.
```
This is the safer default because removing a node that still owns slots would mean permanently losing every key in those slots — there's no implicit "migrate on delete" behavior. Forcing you to reshard first (an explicit, inspectable, resumable operation) rather than letting `del-node` silently discard live data trades a bit of convenience for making data loss something you have to go out of your way to cause, not something a single mistyped command can do by accident.
