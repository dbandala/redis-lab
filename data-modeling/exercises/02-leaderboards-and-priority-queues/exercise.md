# Exercise 02 — Leaderboards and Priority Queues

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Create `leaderboard:fans:weekly:2026-41` with five fans and scores of your choosing (at least one pair with different scores).
2. Increase one fan's score by `50` in a single command, then read the full leaderboard highest-to-lowest with scores.
3. Get the rank (from the top) and score of one specific fan in a single command.
4. Fetch only the top 3 using `BYSCORE`/`REV`/`LIMIT` (not a plain index range) — confirm it matches the first 3 entries from task 2.
5. Copy the top 3 into a new key `leaderboard:fans:weekly:2026-41:top3` using `ZRANGESTORE`, then confirm its contents with `ZRANGE ... WITHSCORES`.
6. Trim the original leaderboard down to just its top 3 members using `ZREMRANGEBYRANK` (don't just re-create it) — confirm `ZCARD` is now `3`.
7. Build a priority queue `queue:support:priority` with 4 tickets at different priorities (lower number = more urgent), then pop the two most urgent in order using `ZPOPMIN`.

Check your answers against [solutions/02-leaderboards-and-priority-queues/solution.md](../../solutions/02-leaderboards-and-priority-queues/solution.md).
