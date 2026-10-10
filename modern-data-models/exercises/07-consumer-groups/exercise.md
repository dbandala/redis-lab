# Exercise 07 — Consumer Groups & Reliable Processing

Use a fresh stream `stream:pulse:orders:practice` and group `grp:practice` for this exercise. Note the actual IDs `redis-cli` returns as you go — you'll need them for later steps.

1. Create the group with `XGROUP CREATE ... $ MKSTREAM`, then append four orders (any fields you like, e.g. `event`, `user`, `qty`).
2. Have `consumer-a` read the first **three** orders with `XREADGROUP ... COUNT 3 ... >`.
3. Run `XPENDING` (summary form). How many entries are pending, and for which consumer?
4. `XACK` the *first* of the three pending entries. Run the summary `XPENDING` again to confirm it dropped to 2.
5. Pretend `consumer-a` crashed holding the second pending entry. Use `XCLAIM` to hand that specific entry to `consumer-b`.
6. Have `consumer-b` read the backlog with `XREADGROUP ... COUNT 10 ... >`. Which order comes back, and why wasn't it included in step 2's read?
7. Run `XAUTOCLAIM` for a third consumer, `consumer-c`, with a minimum idle time of `0`, to sweep up everything still pending. How many entries does it claim?
8. `XACK` everything `consumer-c` just claimed and confirm `XPENDING` is empty again.

Check your answers against [solutions/07-consumer-groups/solution.md](../../solutions/07-consumer-groups/solution.md).
