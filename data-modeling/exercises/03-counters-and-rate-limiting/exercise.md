# Exercise 03 — Counters and Rate Limiting

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Build a fixed-window limiter key `ratelimit:fixed:user:7:w0` with a limit of 2 per 30-second window: increment it, set its TTL with `EXPIRE ... NX` only on the first hit, then increment it two more times. At which call does the count exceed the limit of 2?
2. Call `EXPIRE ratelimit:fixed:user:7:w0 30 NX` again now that the key already has a TTL. What does it return, and why doesn't it reset the window?
3. Build a sliding-window log key `ratelimit:sliding:user:7` by adding 4 timestamps (use `` `date +%s` `` shifted by a few seconds each, or just hand-pick ascending integers) as both score and a uniquely-suffixed member.
4. Prune anything older than a 10-second window relative to your most recent timestamp using `ZREMRANGEBYSCORE`, then get the count with `ZCARD`. Should any entries have been pruned, given the timestamps you chose?
5. In your own words: why does the sliding-window log need a *unique* member per request (e.g. `req:<timestamp>:<n>`) instead of just using the timestamp as the member?

Check your answers against [solutions/03-counters-and-rate-limiting/solution.md](../../solutions/03-counters-and-rate-limiting/solution.md).
