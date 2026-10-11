# Exercise 04 — Distributed Locks & Redlock

Work from the project root so `exercises/02-client-libraries-and-connection-pooling` (for `pulse_pool.py`) is importable.

1. Reproduce the naive-release bug: acquire `lock:refund:evt1` with a short TTL (e.g. 200ms) and a random token, sleep past the TTL, have a second "caller" acquire the now-expired lock with its own token, then call a bare `DEL lock:refund:evt1`. Confirm the key is gone — i.e. confirm you just deleted the *second* caller's valid lock, not your own expired one.
2. Implement a safe release function using the classic Lua compare-and-delete script. Confirm releasing with the wrong token returns `0` and leaves the key in place, and releasing with the correct token returns `1` and removes it.
3. Implement the same safe release using `DELEX key IFEQ value` instead. Confirm the same wrong-token/correct-token behavior.
4. Implement `redlock_acquire(resource, ttl_ms)` against **5 keys** (`lock:<resource>:replica:0` … `replica:4`) on this lab's single instance, requiring a quorum of 3. Test three scenarios: (a) all 5 replicas free — acquired; (b) 2 of 5 pre-held by someone else — still acquired (quorum of 3 reachable from the remaining 3); (c) 3 of 5 pre-held — **not** acquired, and confirm your function released whatever partial locks it *did* acquire rather than leaking them.
5. In your own words (a code comment or terminal note is fine), explain what a fencing token adds that the lock alone doesn't — specifically, what failure mode it protects against that the Lua/`DELEX` safe-release alone does not.
6. Name one Pulse scenario where you'd reach for a database-level guarantee (a unique constraint, a conditional update) instead of a Redis lock, and why.

Compare your work against [solution.md](solution.md) once you're done — not before.
