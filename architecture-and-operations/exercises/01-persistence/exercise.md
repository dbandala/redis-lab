# Exercise 01 — Persistence

Run these against the base lab (`docker exec redis-architecture-and-operations redis-cli ...`).

1. Check the current `save` rule and `appendonly`/`appendfsync` settings with `CONFIG GET`.
2. Write three keys: `pulse:event:evt10`, `pulse:event:evt11`, `pulse:event:evt12` (any string values).
3. Run `SAVE`, then `LASTSAVE`, then list `/data` (`docker exec redis-architecture-and-operations ls -la /data`). Which file did `SAVE` produce?
4. Set `appendfsync` to `always`, confirm it with `CONFIG GET`, then set it back to `everysec`. In one sentence, what would you be trading away if you left it on `always` for a high-throughput workload?
5. Run `BGREWRITEAOF`, then list `/data/appendonlydir`. Name the three files you see and what each one is for.
6. Conceptual: `save` is `60 1` and `appendfsync` is `everysec`. The server crashes 5 seconds after the last write, with no manual `SAVE` in between. On restart, does Redis lose ~60 seconds of data or ~1 second? Which file does it load from, and why does that answer the question?

Check your answers against [solutions/01-persistence/solution.md](../../solutions/01-persistence/solution.md).
