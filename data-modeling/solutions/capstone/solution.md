# Solution — Capstone: Pulse Live Events: Ticket Launch Night

```
$ docker exec redis-data-modeling redis-cli GEOADD geo:venues -122.4194 37.7749 "venue:moscone" -122.4015 37.7835 "venue:chase-center" -122.2585 37.8044 "venue:oracle-arena"
(integer) 3
$ docker exec redis-data-modeling redis-cli GEOSEARCH geo:venues FROMLONLAT -122.41 37.78 BYRADIUS 5 km ASC WITHDIST
1) 1) "venue:chase-center"
   2) "0.8425"
2) 1) "venue:moscone"
   2) "1.0025"
```
`venue:oracle-arena` (across the bay) correctly falls outside the 5km radius.

```
$ docker exec redis-data-modeling redis-cli SET inventory:ticket:evt100:GA 50
OK
$ docker exec redis-data-modeling redis-cli SET inventory:ticket:evt100:VIP 10
OK
```

```
$ cat ticketlib.lua | docker exec -i redis-data-modeling redis-cli -x FUNCTION LOAD REPLACE
"ticketlib"
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:GA 2
(integer) 48
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:GA 1000
(integer) -1
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:GA
"48"
```
The over-reservation attempt returns `-1` and leaves GA inventory untouched at `48` — the Function's check-then-decrement runs atomically, so it never goes negative.

```
$ docker exec redis-data-modeling redis-cli PFADD hll:event:evt100:visitors:launch fan:1 fan:2 fan:3 fan:4 fan:5
(integer) 1
$ docker exec redis-data-modeling redis-cli PFCOUNT hll:event:evt100:visitors:launch
(integer) 5
```

```
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:launch 1 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:launch 2 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:launch 5 1
(integer) 0
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:launch
(integer) 3
```

```
$ docker exec redis-data-modeling redis-cli ZADD leaderboard:fans:global 120 fan:ada 95 fan:grace 150 fan:linus
(integer) 3
$ docker exec redis-data-modeling redis-cli ZINCRBY leaderboard:fans:global 10 fan:grace
"105"
$ docker exec redis-data-modeling redis-cli ZRANGE leaderboard:fans:global 0 1 REV WITHSCORES
1) "fan:linus"
2) "150"
3) "fan:ada"
4) "120"
```

```
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:900:w0
(integer) 1
$ docker exec redis-data-modeling redis-cli EXPIRE ratelimit:fixed:user:900:w0 1800 NX
(integer) 1
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:900:w0
(integer) 2
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:900:w0
(integer) 3
$ docker exec redis-data-modeling redis-cli INCR ratelimit:fixed:user:900:w0
(integer) 4
```
The 4th call returns `4`, exceeding the limit of `3` — the application rejects that purchase attempt.

```
$ # terminal A
$ ./simulate-concurrent-update.sh inventory:ticket:evt100:VIP 1 1
Waiting 1s before the concurrent update...
Decrementing inventory:ticket:evt100:VIP by 1 from a second connection...
(integer) 9
$ # terminal B, started just before A, paused ~2s before EXEC
$ docker exec -i redis-data-modeling redis-cli --no-raw
WATCH inventory:ticket:evt100:VIP
OK
MULTI
OK
HSET reservation:res_launch1 user_id 900 qty 1
QUEUED
DECRBY inventory:ticket:evt100:VIP 1
QUEUED
EXEC
(nil)
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:VIP
"9"
```
`EXEC` aborts (`nil`) — terminal A's concurrent decrement landed on the watched key first. Retrying with no concurrent writer this time succeeds:
```
$ docker exec -i redis-data-modeling redis-cli --no-raw
WATCH inventory:ticket:evt100:VIP
OK
MULTI
OK
HSET reservation:res_launch1 user_id 900 qty 1
QUEUED
DECRBY inventory:ticket:evt100:VIP 1
QUEUED
EXEC
1) (integer) 2
2) (integer) 8
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:VIP
"8"
```

```
$ docker exec redis-data-modeling redis-cli FCALL reserve_ticket 1 inventory:ticket:evt100:VIP 8
(integer) 0
$ docker exec redis-data-modeling redis-cli GET inventory:ticket:evt100:VIP
"0"
```

```
$ # terminal A
$ docker exec -it redis-data-modeling redis-cli SUBSCRIBE "events:evt100:updates"
1) "subscribe"
2) "events:evt100:updates"
3) (integer) 1
$ # terminal B
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt100:updates" "SOLD OUT: VIP"
(integer) 1
```
Terminal A immediately receives:
```
1) "message"
2) "events:evt100:updates"
3) "SOLD OUT: VIP"
```

```
$ bash verify.sh
PASS: geo:venues is a zset under the hood
PASS: geo:venues has 3 venues indexed
PASS: GA inventory decremented, not negative
PASS: VIP inventory sold out
PASS: ticketlib Function is loaded
PASS: unique visitors tracked
PASS: daily-active bitmap has activity
PASS: leaderboard has at least 3 fans
PASS: rate limiter key exists with a TTL
PASS: VIP reservation hash was recorded

Results: 10 passed, 0 failed
```

**Why GA uses a Function but VIP uses `WATCH`:** both are the same underlying problem — "don't oversell a counter" — but the capstone deliberately handles them two different ways to make Lesson 09's trade-off concrete. The GA tier is sold through `ticketlib.lua`'s `reserve_ticket` Function: one round trip, no retry logic needed, which is the better fit under the heavy concurrent load a real GA drop would see. The VIP tier is reserved by hand with `WATCH`/`MULTI`/`EXEC` specifically so this capstone could *demonstrate* an aborted `EXEC` and a retry — in a real system, if VIP reservations see the same contention as GA, they'd also move to the Function; `WATCH` earns its keep when contention is low enough that paying for a server-side script isn't worth it, not as a rule that different ticket tiers need different mechanisms.
