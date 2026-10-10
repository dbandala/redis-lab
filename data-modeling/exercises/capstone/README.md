# Capstone — Pulse Live Events: Ticket Launch Night

## Scenario

It's ticket launch night for Pulse event `evt100`. You're building the hot-data layer that handles it: venue search, ticket inventory, a fan leaderboard, unique-visitor tracking, daily-active-fan flags, a per-user purchase limiter, an atomic (and contested) VIP reservation, and a live sold-out announcement. This capstone combines every Level 2 topic into one connected flow: sorted sets, HyperLogLog, bitmaps, geospatial search, transactions with `WATCH`, Pub/Sub, and a Redis Function.

## Rubric

Your solution is complete when:
- All 10 tasks in [exercise.md](exercise.md) have been performed against the lab
- `bash verify.sh` reports `0 failed`
- You can explain why the capstone's VIP reservation uses a `WATCH`/`MULTI`/`EXEC` retry loop while the GA reservation uses an `FCALL`'d Function — i.e. you can restate Lesson 09's trade-off table in your own words for this specific scenario

Compare your work against [solutions/capstone/solution.md](../../solutions/capstone/solution.md) once you're done — not before.
