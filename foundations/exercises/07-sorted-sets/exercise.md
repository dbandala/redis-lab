# Exercise 07 — Sorted Sets

1. Create `leaderboard:game1` with `alice` at 100 points, `bob` at 250, `carol` at 75 — all in one command.
2. Read the whole leaderboard lowest-to-highest with scores shown, then again highest-to-lowest.
3. Look up `bob`'s exact score, and `alice`'s rank (0-based, ascending).
4. Add 50 points to `carol`'s score atomically (don't read her score and `ZADD` it back yourself), then re-read the full leaderboard.
5. Check `OBJECT ENCODING` on `leaderboard:game1`.
6. Try to set `bob`'s score to `10`, but only if `10` is **greater than** his current score. Confirm the update was rejected and his score is unchanged.

Check your answers against [solutions/07-sorted-sets/solution.md](../../solutions/07-sorted-sets/solution.md).
