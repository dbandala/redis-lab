# Exercise 05 — Bitmaps and BITFIELD

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Mark users `3`, `19`, and `88` active in `bitmap:dau:2026-11-01` using `SETBIT`. Confirm with `BITCOUNT`.
2. Mark users `19`, `42`, and `88` active in `bitmap:dau:2026-11-02`.
3. Compute "active on both days" into `bitmap:dau:retained:1101-1102` with `BITOP AND`, then use `BITCOUNT` and `BITPOS` to find which single user it is.
4. Compute "active on at least one day" into `bitmap:dau:reach:1101-1102` with `BITOP OR`, then `BITCOUNT` it. How many users does that give you, and does it match what you'd expect from the two input sets?
5. Using `BITFIELD` on `stats:bitfield:user:19`, set an 8-bit unsigned counter at slot 0 to `200`, then `INCRBY` it by `100` with `OVERFLOW SAT`. What value do you get, and why isn't it `300`?
6. Repeat task 5's `INCRBY` but with default overflow behavior (no `OVERFLOW SAT`) starting fresh from `200`. What value do you get this time, and how is it different from the saturated result?

Check your answers against [solutions/05-bitmaps-and-bitfields/solution.md](../../solutions/05-bitmaps-and-bitfields/solution.md).
