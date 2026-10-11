# Exercise 02 — Replication

Lab for this exercise: `compose/replication.yml` (`redis-repl-primary`, `redis-repl-replica-1`, `redis-repl-replica-2`). Bring it up with `docker compose -f compose/replication.yml up -d` if it isn't already running.

1. Confirm all three nodes see each other: `INFO replication` on the primary should show `connected_slaves:2`; on each replica it should show `role:slave` and `master_link_status:up`.
2. Write `pulse:event:evt30` on the primary, then read it back from **both** replicas. How long did you have to wait — was it noticeable?
3. Try writing directly to `redis-repl-replica-2`. What error do you get, and which config flag controls that behavior?
4. Write `pulse:event:evt31` on the primary, then immediately run `WAIT 2 1000` on the primary. What does the return value mean, and what would it mean if it had returned `1` instead of `2`?
5. Simulate a primary failure: `docker stop redis-repl-primary`. Promote `redis-repl-replica-1` with `REPLICAOF NO ONE`, then point `redis-repl-replica-2` at it with `REPLICAOF redis-repl-replica-1 6379`. Confirm a new write on the promoted node reaches the other replica.
6. Conceptual: list every manual step you just performed in task 5. Which of those steps would a human on-call engineer realistically be too slow to perform within seconds of a real 3am outage — and is that list of steps the same thing Sentinel (next lesson) automates?

Check your answers against [solutions/02-replication/solution.md](../../solutions/02-replication/solution.md).
