# Exercise 06 — Redis Streams Fundamentals

Use a fresh stream, `stream:pulse:activity:practice`, for this exercise. Note the actual IDs `redis-cli` gives you back — you'll need the first one for step 3.

1. Append three entries for `event` = `evt400`, `user` = `u21`: an `action view`, then an `action favorite`, then an `action purchase` with an extra field `qty 4`.
2. Run `XLEN` and `XRANGE - +` to confirm all three are there in order.
3. Run `XREAD` for everything *after* the first entry's ID. How many entries come back, and why not three?
4. Append a fourth entry (`action refund`) using `XADD ... MAXLEN 2 * ...`. What does `XLEN` report now, and which two entries survived?
5. Why did the `view` and `favorite` entries disappear in step 4 but not the `purchase` entry?

Check your answers against [solutions/06-streams-fundamentals/solution.md](../../solutions/06-streams-fundamentals/solution.md).
