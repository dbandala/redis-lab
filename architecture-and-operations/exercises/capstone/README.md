# Capstone — Pulse Uptime

## Scenario

Pulse's Redis layer is moving from "a cache that's usually up" to "infrastructure that survives a primary dying at 3am without anyone paging in." This capstone combines every Level 4 topic into one connected setup: durable persistence tuned for Pulse's no-lost-writes SLA (Lesson 01), a primary/replica topology (Lesson 02) monitored by Sentinel for automatic failover (Lesson 03), a least-privilege ACL service account instead of the wide-open default user (Lesson 08), and a bounded memory budget with real eviction (Lesson 06) — then `verify.sh` actually kills the primary and proves the whole thing survives the failure with every one of those protections intact on whichever node ends up in charge.

Redis Cluster (Lessons 04–05) and TLS (Lesson 09) are **stretch tasks**, not part of the scripted check — not because they're less important, but because Cluster has its own independent per-shard failover mechanism that doesn't combine with Sentinel-monitored primary/replica the way the rest of this capstone's pieces combine with each other. There's no single real-world topology that runs both at once over the same data.

## Rubric

Your solution is complete when:
- All 7 tasks in [exercise.md](exercise.md) have been performed against the lab
- `bash exercises/capstone/verify.sh` reports `0 failed`
- You can explain why every configuration task had to be applied to all three nodes individually, not just the primary
- You can explain, after inspecting the old primary post-restart in task 7, why its ACL user and eviction policy reset to defaults — and what a production deployment would configure differently (from Lesson 08) so that doesn't happen

Compare your work against [solutions/capstone/solution.md](../../solutions/capstone/solution.md) once you're done — not before.
