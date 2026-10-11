# Solution 03 — Sentinel & High Availability

```
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL ckquorum pulse-primary
OK 3 usable Sentinels. Quorum and failover authorization can be reached
```
All 3 Sentinels are up and reachable, so a failover vote could succeed if needed. This depends on the `2` in `sentinel monitor pulse-primary redis-sentinel-primary 6379 2` — that's the quorum number, the minimum Sentinels that must agree the primary is down before a failover can even be attempted.

```
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name pulse-primary
172.21.0.2
6379
$ docker exec redis-sentinel-primary redis-cli INFO replication | grep -E "role:|master_repl_offset"
role:master
master_repl_offset:8446
```
`172.21.0.2` is `redis-sentinel-primary`'s address on the Docker network — matches what Sentinel reports, and the node itself confirms `role:master`.

```
$ docker stop redis-sentinel-primary
redis-sentinel-primary
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name pulse-primary   # polled once per second
... unchanged for 5 seconds ...
172.21.0.4      # changed at t=6s
6379
```
6 seconds in this lab's tuned config. That delay is `sentinel down-after-milliseconds pulse-primary 5000` — Sentinel won't even consider the primary down until 5000ms of failed pings have elapsed, plus a little time for the quorum vote and promotion itself. Production's default is 30000ms (30s), deliberately tuned down here for a responsive classroom demo.

```
$ docker exec redis-sentinel-replica-1 redis-cli INFO replication | grep -m1 role
role:master
$ docker exec redis-sentinel-replica-2 redis-cli INFO replication | grep -m1 role
role:slave
```
Sentinel promoted `redis-sentinel-replica-1` and reconfigured `redis-sentinel-replica-2` to follow it.

```
$ docker start redis-sentinel-primary
redis-sentinel-primary
$ docker exec redis-sentinel-primary redis-cli INFO replication | grep -m1 role   # polled once per second
... role:master for 9 seconds (it still thinks it's the primary on boot) ...
role:slave      # at t=10s
```
10 seconds — a *different* knob: `sentinel failover-timeout pulse-primary 10000`. This governs the overall failover operation window, including reconfiguring any node (like the returning old primary) that needs to be told to follow the new one. `down-after-milliseconds` answers "how long until Sentinel suspects trouble"; `failover-timeout` answers "how long the whole remediation process is allowed to take."

**Step 6:** No — with only 1 Sentinel running, quorum `2` could never be satisfied, so that lone Sentinel would detect the primary is unreachable (from its own point of view) but would **not** be authorized to start a failover; it would just sit there repeatedly failing to reach quorum. Quorum `2` requires that at least two independently-running Sentinel processes agree the primary is actually down before any failover begins — this is specifically a defense against one Sentinel's own network partition or host hiccup (which makes the primary look unreachable *to that Sentinel alone*, even though it's perfectly healthy and reachable by everyone else) triggering a false, disruptive failover. A single Sentinel has no second opinion to check itself against, so Redis deliberately refuses to let one Sentinel act alone.
