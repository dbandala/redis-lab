# Solution 04 — Redis Cluster Fundamentals

```
$ docker exec redis-cluster-1 redis-cli CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
```

```
$ docker exec redis-cluster-1 redis-cli CLUSTER KEYSLOT pulse:event:evt1
(integer) 13262
$ docker exec redis-cluster-1 redis-cli CLUSTER NODES | grep master
c55e673... 172.21.0.6:6379@16379 master - ... connected 5461-10922
a10f693... 172.21.0.3:6379@16379 myself,master - ... connected 0-5460
0bcc681... 172.21.0.8:6379@16379 master - ... connected 10923-16383
```
Slot 13262 falls in `10923-16383`, so `redis-cluster-3` (`0bcc681...`) owns this key — not `redis-cluster-1`, the node we're running commands from.

```
$ docker exec redis-cluster-1 redis-cli -c SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-cluster-1 redis-cli -c GET pulse:event:evt1
"Night Lights Festival"
```
Both succeeded even though node 1 doesn't own this slot, because `-c` makes `redis-cli` transparently follow the `MOVED` redirect to the owning node (`redis-cluster-3`) itself — you never see the redirect happen.

```
$ docker exec redis-cluster-1 redis-cli -c MSET pulse:event:evt1 x pulse:event:evt2 y
(error) CROSSSLOT Keys in request don't hash to the same slot
```
`pulse:event:evt1` and `pulse:event:evt2` hash to different slots (nothing ties them together), and Cluster has no mechanism to atomically write across two different nodes in one command — so it refuses outright rather than silently split the operation.

```
$ docker exec redis-cluster-1 redis-cli -c MSET '{pulse:evt1}:name' "Night Lights" '{pulse:evt1}:venue' "Riverside Park"
OK
$ docker exec redis-cluster-1 redis-cli CLUSTER KEYSLOT '{pulse:evt1}:name'
(integer) 14579
$ docker exec redis-cluster-1 redis-cli CLUSTER KEYSLOT '{pulse:evt1}:venue'
(integer) 14579
```
Identical slot — the `{pulse:evt1}` hash tag told Cluster to hash only that substring for both keys, deliberately co-locating them so they can be written together atomically.

**Step 6:** `redis-cli -c` (and every cluster-aware client) follows a `MOVED` redirect by opening a **new connection to the address the server gave it** — here, a Docker-internal IP like `172.21.0.6:6379`. From inside the Docker network, that address is real and reachable. From your host terminal connecting through the published port `6400`, your `redis-cli` process is *not* on that Docker network — `172.21.0.6` means nothing to it, and the connection attempt fails or hangs. This is exactly the NAT/gossip mismatch the lesson's "biggest gotcha" callout describes: Docker's port-publishing only maps one port on one specific container, it doesn't make every cluster node's internal address reachable from outside — which is why every command in this lesson runs via `docker exec` into a node container instead.
