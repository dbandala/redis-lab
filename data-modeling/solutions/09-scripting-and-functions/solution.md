# Solution 09 — Lua Scripting and Redis Functions

```
$ docker exec redis-data-modeling redis-cli SET checkin:count:evt100 0
OK
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local cap=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current < cap then return redis.call('INCR', key) else return -1 end" 1 checkin:count:evt100 3
(integer) 1
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local cap=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current < cap then return redis.call('INCR', key) else return -1 end" 1 checkin:count:evt100 3
(integer) 2
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local cap=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current < cap then return redis.call('INCR', key) else return -1 end" 1 checkin:count:evt100 3
(integer) 3
$ docker exec redis-data-modeling redis-cli EVAL "local key=KEYS[1] local cap=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current < cap then return redis.call('INCR', key) else return -1 end" 1 checkin:count:evt100 3
(integer) -1
```
The 4th call returns `-1` — the counter is already at `3`, equal to the capacity, so the `current < cap` check fails and `INCR` never runs. The check and the increment must happen inside one script (not as a client-side `GET` followed by a conditional `INCR`) because between those two separate round trips, another client could also read `2`, also decide it's under capacity, and also increment — both would succeed and the counter would overshoot to `4`. Running both steps as one atomic script execution closes that window entirely, the same guarantee `MULTI`/`EXEC` gives a fixed batch, but with a mid-script conditional that plain `MULTI` queuing can't express.

```
$ docker exec redis-data-modeling redis-cli SCRIPT LOAD "local key=KEYS[1] local cap=tonumber(ARGV[1]) local current=tonumber(redis.call('GET',key)) if current < cap then return redis.call('INCR', key) else return -1 end"
"3f5784b28406a0f3a11926de6945d744dbba01b6"
$ docker exec redis-data-modeling redis-cli EVALSHA 3f5784b28406a0f3a11926de6945d744dbba01b6 1 checkin:count:evt100 10
(integer) 4
$ docker exec redis-data-modeling redis-cli SCRIPT FLUSH
OK
$ docker exec redis-data-modeling redis-cli EVALSHA 3f5784b28406a0f3a11926de6945d744dbba01b6 1 checkin:count:evt100 10
(error) NOSCRIPT No matching script. Please use EVAL.
```
After `SCRIPT FLUSH`, the server no longer has that hash cached, so `EVALSHA` fails with `NOSCRIPT`. A production client library handles this by catching `NOSCRIPT` and automatically falling back to a full `EVAL` of the original script text (then re-caching it) — which is extra client-side bookkeeping that `FUNCTION`/`FCALL` doesn't need, since a loaded Function library is never silently evicted the way the script cache can be flushed.

```
$ docker exec redis-data-modeling redis-cli SET inventory:ticket:evt100:VIP 5
OK
$ cat ticketlib.lua | docker exec -i redis-data-modeling redis-cli -x FUNCTION LOAD REPLACE
"ticketlib"
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:VIP 2
(integer) 3
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:VIP 10
(integer) -1
```
Reserving `2` of the `5` available succeeds, leaving `3`; reserving `10` more (more than remain) correctly returns `-1` without touching the counter.

```
$ docker exec redis-data-modeling redis-cli FUNCTION LIST
1) 1) "library_name"
   2) "ticketlib"
   3) "engine"
   4) "LUA"
   5) "functions"
   6) 1) 1) "name"
         2) "reserve_ticket"
         3) "description"
         4) (nil)
         5) "flags"
         6) (empty array)
```
`FUNCTION LIST` shows the loaded library and every function it registers — a stable, named, inspectable catalog, unlike `SCRIPT LOAD`'s bare hash. Critically, a loaded Function library is persisted to RDB/AOF and replicated like regular data, so a restart does **not** lose it the way `SCRIPT FLUSH` wiped the cached script above — you'd need to explicitly `FUNCTION DELETE ticketlib` (or flush functions) to remove it, not just restart the server.
