# Capstone Exercise — Pulse Live Events: Ticket Launch Night

Work through these in order against the lab. A few tasks need a second terminal — they're marked.

1. **Venues.** Create `geo:venues` with three venues of your choosing (longitude, latitude, name) — at least two should be within 5km of each other. Run a `GEOSEARCH ... FROMLONLAT ... BYRADIUS 5 km` near your close pair and confirm the far venue is excluded.

2. **Inventory.** Set `inventory:ticket:evt100:GA` to `50` and `inventory:ticket:evt100:VIP` to `10`.

3. **GA reservation via Function.** Load `../09-scripting-and-functions/ticketlib.lua` with `FUNCTION LOAD REPLACE`. Use `FCALL reserve_ticket` to reserve `2` GA tickets, then attempt to reserve `1000` more and confirm it's rejected (`-1`) without going negative.

4. **Unique visitors.** `PFADD` at least 5 distinct fan ids into `hll:event:evt100:visitors:launch`, then `PFCOUNT` it.

5. **Daily-active fans.** `SETBIT` at least 3 user ids active in `bitmap:dau:launch`, then confirm the count with `BITCOUNT`.

6. **Leaderboard.** `ZADD` at least 3 fans with scores into `leaderboard:fans:global`, `ZINCRBY` one of them, then read the top 2 with `ZRANGE ... REV WITHSCORES`.

7. **Purchase rate limiter.** Using key `ratelimit:fixed:user:900:w0`, a limit of `3`, and a 1800-second window (the fixed-window pattern from Lesson 03 — long enough that it won't expire before you run `verify.sh`), make 4 calls and confirm the 4th exceeds the limit.

8. **Contested VIP reservation (two terminals).** In terminal A, run `../07-transactions-and-watch/simulate-concurrent-update.sh inventory:ticket:evt100:VIP 1 1`. In terminal B, immediately run a `WATCH inventory:ticket:evt100:VIP` → `MULTI` → `HSET reservation:res_launch1 user_id 900 qty 1` → `DECRBY inventory:ticket:evt100:VIP 1` → (pause ~2s) → `EXEC` sequence. Confirm `EXEC` aborts (`nil`). Retry the same `WATCH`/`MULTI`/`EXEC` sequence once more (no concurrent script running this time) and confirm it succeeds.

9. **Sell out and announce.** Use `FCALL reserve_ticket` to reserve whatever VIP inventory remains, bringing `inventory:ticket:evt100:VIP` to exactly `0`. In one terminal, `SUBSCRIBE "events:evt100:updates"`; from another, `PUBLISH "events:evt100:updates" "SOLD OUT: VIP"` and confirm the subscriber receives it.

10. Run `bash verify.sh` and get every check to `PASS`.

Check your answers against [solutions/capstone/solution.md](../../solutions/capstone/solution.md).
