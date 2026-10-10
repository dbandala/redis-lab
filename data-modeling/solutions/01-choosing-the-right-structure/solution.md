# Solution 01 — Choosing the Right Structure

```
$ docker exec redis-data-modeling redis-cli HSET session:tok_demo1 user_id 7 event_id evt200
(integer) 2
$ docker exec redis-data-modeling redis-cli EXPIRE session:tok_demo1 900
(integer) 1
```

```
$ docker exec redis-data-modeling redis-cli HGETALL session:tok_demo1
1) "user_id"
2) "7"
3) "event_id"
4) "evt200"
$ docker exec redis-data-modeling redis-cli TTL session:tok_demo1
(integer) 900
```

```
$ docker exec redis-data-modeling redis-cli INCR stats:pageviews:event:evt200
(integer) 1
$ docker exec redis-data-modeling redis-cli INCR stats:pageviews:event:evt200
(integer) 2
$ docker exec redis-data-modeling redis-cli INCR stats:pageviews:event:evt200
(integer) 3
$ docker exec redis-data-modeling redis-cli INCRBY stats:pageviews:event:evt200 5
(integer) 8
```
Final value: `8` (three single increments plus one `INCRBY 5`).

```
$ docker exec redis-data-modeling redis-cli TYPE session:tok_demo1
hash
$ docker exec redis-data-modeling redis-cli TYPE stats:pageviews:event:evt200
string
```
They're different types because they answer different questions. `session:tok_demo1` is a *record* — several named fields that belong together and expire together, which is exactly what a hash with one `EXPIRE` gives you. `stats:pageviews:event:evt200` is a *running total* — a single number that only ever needs atomic increments, which is what a string plus `INCR`/`INCRBY` gives you. Sharing the same event id doesn't mean they should share a type; the shape of the access pattern decides that, not the domain object they both relate to.

For "has user 7 ever visited event evt200, across millions of users, approximate total is fine" — that's a **bitmap** (one bit per user id, `SETBIT`/`BITCOUNT`), not a `SET` of user ids. A `SET` of a million members costs real memory per member (the member value itself, plus pointer/hash overhead); a bitmap costs exactly one bit per user id regardless of how many are set, so a million-user bitmap over a single day is on the order of 125KB instead of tens of megabytes. We build this in Lesson 05.
