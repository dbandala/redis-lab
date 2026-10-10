# Exercise 04 — HyperLogLog

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Create `hll:event:evt200:visitors:2026-11-01` and add 6 distinct visitor ids to it. Check the count.
2. Add 3 more ids, where 2 are visitors already added in task 1 and 1 is brand new. What's the new count, and does it match what you'd expect?
3. Create a second day's key `hll:event:evt200:visitors:2026-11-02` with 4 visitor ids, 2 of which overlap with day 1.
4. Get the estimated combined unique-visitor count across both days with a single command, without creating a third key.
5. Now actually merge both days into `hll:event:evt200:visitors:total` and confirm its count matches what you got in task 4.
6. Check `STRLEN` on `hll:event:evt200:visitors:total`. Why is it so small compared to storing every visitor id in a `SET` would be, once you imagine this running for a sold-out stadium event with 50,000 attendees?

Check your answers against [solutions/04-hyperloglog/solution.md](../../solutions/04-hyperloglog/solution.md).
