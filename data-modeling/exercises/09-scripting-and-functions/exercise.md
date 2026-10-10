# Exercise 09 — Lua Scripting and Redis Functions

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session). This module ships `ticketlib.lua` in this exercise's directory — the same Function library from the lesson.

1. Set `checkin:count:evt100` to `0`. Write and run (via `EVAL`) a script that atomically increments it **only if** it's currently below a capacity of `3`, returning `-1` otherwise (`KEYS[1]` = the key, `ARGV[1]` = the capacity). Call it 4 times. What happens on the 4th call, and why does the check-then-increment need to happen inside the script rather than as two separate commands from the client?
2. Cache your script with `SCRIPT LOAD`, note the returned SHA, and call it once via `EVALSHA`. Then run `SCRIPT FLUSH` and call the same `EVALSHA` again. What error do you get, and what would a production client need to do in response?
3. Set `inventory:ticket:evt100:VIP` to `5`. Load `ticketlib.lua` with `FUNCTION LOAD REPLACE` (pipe the file into `redis-cli -x`, the same way the lesson did it). Call `FCALL reserve_ticket` to reserve `2` VIP tickets, then try to reserve `10` more. What do you get back for each call?
4. Run `FUNCTION LIST`. What does it report, and how is this different from what `SCRIPT LOAD` gave you in task 2 — specifically, would a Redis restart lose what `FUNCTION LIST` shows, the way `SCRIPT FLUSH` wiped your cached script?

Check your answers against [solutions/09-scripting-and-functions/solution.md](../../solutions/09-scripting-and-functions/solution.md).
