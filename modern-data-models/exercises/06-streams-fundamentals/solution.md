# Solution 06 — Redis Streams Fundamentals

```
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity:practice * event evt400 action view user u21
"1791590936023-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity:practice * event evt400 action favorite user u21
"1791590936088-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity:practice * event evt400 action purchase user u21 qty 4
"1791590936161-0"
```

```
$ docker exec redis-modern-data-models redis-cli XLEN stream:pulse:activity:practice
(integer) 3
$ docker exec redis-modern-data-models redis-cli XRANGE stream:pulse:activity:practice - +
1) 1) "1791590936023-0"
   2) 1) "event" 2) "evt400" 3) "action" 4) "view" 5) "user" 6) "u21"
2) 1) "1791590936088-0"
   2) 1) "event" 2) "evt400" 3) "action" 4) "favorite" 5) "user" 6) "u21"
3) 1) "1791590936161-0"
   2) 1) "event" 2) "evt400" 3) "action" 4) "purchase" 5) "user" 6) "u21" 7) "qty" 8) "4"
```
All three entries, oldest to newest — `XRANGE - +` always reads in ID order, which here is also insertion order.

```
$ docker exec redis-modern-data-models redis-cli XREAD COUNT 10 STREAMS stream:pulse:activity:practice 1791590936023-0
1) 1) "stream:pulse:activity:practice"
   2) 1) 1) "1791590936088-0"
         2) 1) "event" 2) "evt400" 3) "action" 4) "favorite" 5) "user" 6) "u21"
      2) 1) "1791590936161-0"
         2) 1) "event" 2) "evt400" 3) "action" 4) "purchase" 5) "user" 6) "u21" 7) "qty" 8) "4"
```
Two entries, not three. `XREAD` with an explicit ID returns everything **after** it, exclusive — the ID you pass marks "I've already seen up to and including this one," so the entry at that exact ID is never returned twice.

```
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:activity:practice MAXLEN 2 * event evt400 action refund user u21
"1791590941068-0"
$ docker exec redis-modern-data-models redis-cli XLEN stream:pulse:activity:practice
(integer) 2
$ docker exec redis-modern-data-models redis-cli XRANGE stream:pulse:activity:practice - +
1) 1) "1791590936161-0"
   2) 1) "event" 2) "evt400" 3) "action" 4) "purchase" 5) "user" 6) "u21" 7) "qty" 8) "4"
2) 1) "1791590941068-0"
   2) 1) "event" 2) "evt400" 3) "action" 4) "refund" 5) "user" 6) "u21"
```
`XLEN` reports `2`. The surviving entries are the `purchase` (3rd written) and the new `refund` (4th written) — the two **newest** entries.

The `view` and `favorite` entries disappeared because `MAXLEN 2` trims from the **oldest** end every time the stream would exceed 2 entries after the write — it keeps the most recent N, not any particular entry by content. `purchase` survived not because it was a purchase specifically, but purely because it was newer than `view`/`favorite` at the moment the trim ran. If you need to guarantee specific entries (e.g., "never trim purchase records") you can't rely on `MAXLEN` alone — you'd route those into a separate stream, or a non-trimmed structure, instead of mixing retention policies within one stream.
