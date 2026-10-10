# Exercise 07 — Transactions: MULTI/EXEC/WATCH

Run these against the lab. Tasks 1–2 use a single `docker exec -i ... redis-cli --no-raw <<'EOF' ... EOF` heredoc (or an interactive `redis-cli` session) so `MULTI`/`EXEC` share one connection. Task 4 needs **two terminals**.

1. Set `inventory:ticket:evt100:GA` to `20`. In one `MULTI`/`EXEC` batch, `DECRBY` it by `3` and `HSET` a new `reservation:res_ex1` hash with `user_id` `99` and `qty` `3`. Confirm the final inventory value.
2. Start a new `MULTI`, queue a `DECRBY inventory:ticket:evt100:GA 10`, then `DISCARD` instead of `EXEC`. Confirm the inventory value is unchanged from task 1.
3. This module ships a helper script, `simulate-concurrent-update.sh <key> <amount> [delay-seconds]`, that waits `delay-seconds` then decrements `<key>` by `<amount>` from its own connection — it exists to simulate "some other client" racing you to a watched key.
4. In **terminal A**, run: `./simulate-concurrent-update.sh inventory:ticket:evt100:GA 1 1` (waits 1 second, then decrements by 1). Immediately after starting it, in **terminal B**, run a `WATCH inventory:ticket:evt100:GA` → `MULTI` → `DECRBY inventory:ticket:evt100:GA 5` → (pause ~2 seconds, e.g. by typing slowly or adding a `sleep 2` before the next line if scripting it) → `EXEC`. What does `EXEC` return, and what's the inventory value afterward?
5. Re-run just the `WATCH`/`MULTI`/`DECRBY 5`/`EXEC` sequence from task 4 (terminal B only, no concurrent script running this time). Does it succeed now? What's the new inventory value?

Check your answers against [solutions/07-transactions-and-watch/solution.md](../../solutions/07-transactions-and-watch/solution.md).
