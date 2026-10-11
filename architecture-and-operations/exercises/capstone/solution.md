# Solution — Capstone: Pulse Uptime

## Setup (all three nodes)

```
$ for n in redis-sentinel-primary redis-sentinel-replica-1 redis-sentinel-replica-2; do
    docker exec $n redis-cli CONFIG SET appendfsync always
    docker exec $n redis-cli ACL SETUSER pulse-api on '>s3cret-api-pass' '~pulse:*' '+get' '+set' '+expire' resetchannels
    docker exec $n redis-cli CONFIG SET maxmemory 64mb
    docker exec $n redis-cli CONFIG SET maxmemory-policy allkeys-lru
  done
```
Every one of these ran on all three nodes — had any of them only run on `redis-sentinel-primary`, the moment Sentinel promotes a different node, that hardening would simply not exist on the node now serving traffic.

```
$ docker exec redis-sentinel-primary redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-sentinel-primary redis-cli WAIT 2 1000
(integer) 2
```
`WAIT 2 1000` returning `2` confirms both replicas already have this write before moving on — not strictly required by the task, but it's the right habit for anything about to be failover-tested.

```
$ docker exec sentinel-1 redis-cli -p 26379 SENTINEL ckquorum pulse-primary
OK 3 usable Sentinels. Quorum and failover authorization can be reached
```

## `verify.sh`

```
PASS: appendfsync is 'always' on the primary
PASS: pulse-api ACL user exists on the primary
PASS: pulse-api can read pulse:* but not run FLUSHALL
PASS: maxmemory-policy is allkeys-lru on the primary
PASS: pulse:event:evt1 exists and replicated to both replicas
PASS: Sentinel quorum is healthy before the failover test
PASS: Sentinel promoted a new primary within 45s
PASS: exactly one former replica was promoted to master
PASS: the promoted primary still has pulse:event:evt1
PASS: the promoted primary still enforces the pulse-api ACL
PASS: the promoted primary still has maxmemory-policy allkeys-lru
PASS: old primary rejoined as a replica within 45s

Results: 12 passed, 0 failed
```
The middle block of checks is the entire point of the capstone: Sentinel doesn't just move the "primary" label to a different IP — the node it promotes was independently configured in the setup step to carry the same ACL and eviction hardening, and `verify.sh` proves that's still true *after* the failure, not just before it.

## Step 7 — inspecting the old primary after it rejoins

```
$ docker exec redis-sentinel-primary redis-cli ACL LIST
user default on nopass sanitize-payload ~* &* +@all
$ docker exec redis-sentinel-primary redis-cli CONFIG GET maxmemory-policy
maxmemory-policy
noeviction
```
Both reset to defaults — `pulse-api` is gone, `maxmemory-policy` is back to `noeviction`. This is expected, not a bug: `docker stop`/`docker start` stops and restarts the `redis-server` **process**, and both `ACL SETUSER` and `CONFIG SET` are runtime-only, in-memory changes. Nothing in this lab's `compose/sentinel.yml` configured an `aclfile`, and there's no `redis.conf` for `CONFIG REWRITE` to write into — so there was nowhere for either change to be persisted, and the restarted process came back with the compiled-in defaults, exactly like Lesson 08's `aclfile`-is-immutable-and-startup-only finding.

**What a real production deployment would do differently:** configure `--aclfile /etc/redis/users.acl` (pre-populated, or written once via `ACL SAVE` and committed to the node's provisioning) and bake `maxmemory`/`maxmemory-policy` into the node's startup command or `redis.conf` from the very first boot — the same way this lab's `compose/sentinel.yml` already bakes in `--appendonly yes --save 60 1` as startup flags rather than runtime `CONFIG SET` calls. Anything configured only at runtime is one unplanned restart away from silently reverting, which is a dangerous way to find out a production safeguard was never actually durable.

## Stretch tasks

**Cluster:** the 7th-node add → reshard 1000 slots → reshard back → `del-node` → `docker rm`/`volume rm` cycle from Lesson 05, performed against `compose/cluster.yml`, ending with `CLUSTER INFO` showing `cluster_state:ok` and exactly 6 nodes again.

**TLS + why Cluster/Sentinel don't compose:** `docker exec redis-tls redis-cli --tls --cacert /tls/ca.crt -p 6443 PING` without a client cert returns `Error: Server closed the connection`, confirming `tls-auth-clients yes` is enforced. On the conceptual question: Redis Cluster's failover is **per-shard and peer-voted** — each primary's own replicas and cluster peers detect and promote without any Sentinel process involved — while this capstone's Sentinel setup monitors a single primary/replica pair from **outside** processes with their own quorum. A real deployment picks one topology for a given dataset's availability story, not both simultaneously over the same keys: Cluster shards already carry their own failover, and bolting Sentinel onto Cluster nodes would just be monitoring a mechanism Cluster already handles itself.
