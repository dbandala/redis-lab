# Capstone — Mini Blog Hot-Data Layer

## Scenario

You're building the hot-data layer for a small blog: user profiles, login sessions, article tags, view counters, a trending leaderboard, and a recent-activity feed — the kind of read-heavy, latency-sensitive data a real caching layer in front of a primary database would hold. This capstone combines every Level 1 topic into one connected data model: strings, lists, hashes, sets, sorted sets, TTL, key naming, and `SCAN`.

## Rubric

Your solution is complete when:
- All 9 tasks in [exercise.md](exercise.md) have been performed against the lab
- `bash verify.sh` reports `0 failed`
- You can explain, for at least two structures you created, why Redis chose the `OBJECT ENCODING` it did

Compare your work against [solutions/capstone/solution.md](../../solutions/capstone/solution.md) once you're done — not before.
