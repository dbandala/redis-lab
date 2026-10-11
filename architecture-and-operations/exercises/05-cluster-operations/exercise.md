# Exercise 05 — Redis Cluster Operations

Lab for this exercise: the same 6-node `compose/cluster.yml` cluster from Lesson 04, still running. **This exercise changes cluster topology — do every step through step 8, in order, including cleanup.**

1. Start an 8th node ad hoc, on the same Docker network, named `redis-cluster-8`, host port `6407`, with the same `--cluster-enabled` flags as the lesson (adjust the `docker run` command from the lesson — just rename the container/port/volume).
2. Join it to the cluster via `redis-cluster-2` this time (not `redis-cluster-1`): `redis-cli --cluster add-node redis-cluster-8:6379 redis-cluster-2:6379`.
3. Find `redis-cluster-2`'s node ID and your new node's ID from `CLUSTER NODES`, then reshard **500** slots from `redis-cluster-2` onto the new node.
4. Confirm with `CLUSTER NODES` which slot range `redis-cluster-2` kept and which range the new node now owns.
5. Find any key name that hashes into the new node's slot range (trial and error with `CLUSTER KEYSLOT` is fine), then show the raw `MOVED` error for it without `-c`, and the transparent success with `-c`.
6. Reshard the same 500 slots back from the new node to `redis-cluster-2`. What did `CLUSTER NODES` automatically turn the now-empty new node into?
7. Remove it with `--cluster del-node`, then `docker rm -f` the container and remove its volume.
8. Confirm `CLUSTER INFO` shows `cluster_state:ok` and `cluster_slots_assigned:16384`, and that `CLUSTER NODES` lists exactly 6 nodes again — the same shape Lesson 04 left it in.
9. Conceptual: suppose, instead of resharding back in step 6, you'd run `del-node` on the new node *while it still owned 500 slots*. What do you think `redis-cli --cluster del-node` would do, and why would that be the safer default even though it's less convenient?

Check your answers against [solutions/05-cluster-operations/solution.md](../../solutions/05-cluster-operations/solution.md).
