# Capstone — Pulse Uptime

Lab for this capstone: `compose/sentinel.yml` (primary + 2 replicas + 3 Sentinels). Start fresh: `docker compose -f compose/sentinel.yml up -d` (tear down any other Level 4 stack first).

**Every configuration task below must be applied to all three Redis nodes individually** (`redis-sentinel-primary`, `redis-sentinel-replica-1`, `redis-sentinel-replica-2`) — `CONFIG SET` and `ACL SETUSER` are per-process runtime state, never replicated automatically (you confirmed this directly in Lessons 02/08). If you only configure the current primary, the node Sentinel promotes later won't have any of this hardening.

1. **Durability.** Set `appendfsync always` on all three nodes — Pulse's uptime SLA says no acknowledged write may ever be lost, even at the cost of write latency.
2. **Least privilege.** Create an ACL user `pulse-api`, password `s3cret-api-pass`, restricted to keys matching `pulse:*`, allowed only `GET`/`SET`/`EXPIRE`, `resetchannels` — on all three nodes.
3. **Memory management.** Set `maxmemory 64mb` and `maxmemory-policy allkeys-lru` on all three nodes.
4. **Write Pulse data.** As the `pulse-api` user, against the primary: `SET pulse:event:evt1 "Night Lights Festival"`. Then run `WAIT 2 1000` on the primary and confirm it returns `2` — both replicas have the write.
5. **Health check.** Confirm `SENTINEL ckquorum pulse-primary` reports all 3 Sentinels usable before you do anything else.
6. **Run the check:** `bash exercises/capstone/verify.sh`. This script stops the current primary, waits for Sentinel to promote a replica, confirms the new primary still has your data *and* still enforces the ACL and eviction policy you configured in steps 1–3 (this is exactly why step 0's instruction mattered), then restarts the old primary and confirms it rejoins as a replica.
7. After `verify.sh` reports `0 failed`, inspect the **old primary** (now a replica again) with `ACL LIST` and `CONFIG GET maxmemory-policy`. Is your Step 2/3 hardening still there, or did it reset? Explain why, in terms of what you learned in Lesson 08 about `aclfile` being an immutable, startup-only config.

## Stretch tasks (not scripted in `verify.sh`)

- **Cluster:** bring up `compose/cluster.yml`, bootstrap it, and reshard some slots onto a 7th node you add and then remove — Lesson 05's full cycle, from memory, without the lesson open.
- **TLS:** bring up `compose/tls.yml`, confirm a connection without a client cert is rejected, and explain in one sentence why Cluster's built-in per-shard failover and Sentinel's primary/replica failover aren't the same mechanism and don't compose with each other the way this capstone's Sentinel+ACL+eviction setup does.

Check your answers against [solutions/capstone/solution.md](../../solutions/capstone/solution.md) once you're done — not before.
