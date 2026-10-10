# Exercise 01 — Choosing the Right Structure

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Create a session hash `session:tok_demo1` with fields `user_id` = `7` and `event_id` = `evt200`, then give it a 900-second TTL in a separate command.
2. Read back the whole session with one command. Check its `TTL`.
3. Create a page-view counter `stats:pageviews:event:evt200` and increment it 3 times using a single command per increment, then once more by `5` in one call. What's the final value?
4. Run `TYPE` on both `session:tok_demo1` and `stats:pageviews:event:evt200`. Why are they different types even though both "belong to" the same event?
5. Suppose you were tracking "has user 7 ever visited event evt200" across millions of users, where you don't care about an exact count — just yes/no per user and a rough total. Looking at the decision table in the lesson, which structure would you reach for, and why not a plain `SET` of user ids? (No command needed — answer in a comment or just think it through; we'll build this for real in Lesson 05.)

Check your answers against [solutions/01-choosing-the-right-structure/solution.md](../../solutions/01-choosing-the-right-structure/solution.md).
