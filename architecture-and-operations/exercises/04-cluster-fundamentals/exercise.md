# Exercise 04 — Redis Cluster Fundamentals

Lab for this exercise: `compose/cluster.yml`, bootstrapped with `redis-cli --cluster create` (see the lesson). All commands run via `docker exec redis-cluster-1 redis-cli ...` — never against a host-mapped port, for the reason explained in the lesson.

1. Confirm the cluster is healthy: `CLUSTER INFO` should show `cluster_state:ok` and `cluster_slots_assigned:16384`.
2. Run `CLUSTER KEYSLOT pulse:event:evt1` to find its slot, then run `CLUSTER NODES` and identify which primary's slot range contains that number.
3. `SET pulse:event:evt1 "Night Lights Festival"` using `redis-cli -c` from `redis-cluster-1`, even if (per task 2) the owning node isn't node 1. Confirm the `GET` works too. What made this transparent?
4. Try `MSET pulse:event:evt1 x pulse:event:evt2 y` with `-c`. What error do you get, and why?
5. Now use a hash tag to set two related fields atomically in one call: `MSET '{pulse:evt1}:name' "Night Lights" '{pulse:evt1}:venue' "Riverside Park"`. Confirm with `CLUSTER KEYSLOT` on both full key names that they land in the same slot.
6. Conceptual: this lesson's lab always runs commands via `docker exec` into a node container, never against the host-mapped ports (`6400`-`6405`). If you tried `redis-cli -c -p 6400 SET somekey val` from your own terminal and that key's owning node issued a `MOVED` redirect, why would `redis-cli` likely fail to follow it, even with `-c` set?

Check your answers against [solutions/04-cluster-fundamentals/solution.md](../../solutions/04-cluster-fundamentals/solution.md).
