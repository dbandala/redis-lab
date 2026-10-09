# Capstone Solution — Mini Blog Hot-Data Layer

```
$ docker exec redis-foundations redis-cli HSET user:1 name "Ada Lovelace" email "ada@example.com" plan "free"
(integer) 3
$ docker exec redis-foundations redis-cli HSET user:2 name "Grace Hopper" email "grace@example.com" plan "pro"
(integer) 3
$ docker exec redis-foundations redis-cli HSET user:3 name "Linus Torvalds" email "linus@example.com" plan "free"
(integer) 3
```

```
$ docker exec redis-foundations redis-cli SET session:demo "user:1" EX 300
OK
$ docker exec redis-foundations redis-cli TTL session:demo
(integer) 300
```

```
$ docker exec redis-foundations redis-cli SADD article:1:tags "redis" "databases" "nosql"
(integer) 3
$ docker exec redis-foundations redis-cli SADD article:2:tags "redis" "caching" "performance"
(integer) 3
$ docker exec redis-foundations redis-cli SADD article:3:tags "postgres" "sql" "databases"
(integer) 3
$ docker exec redis-foundations redis-cli SINTER article:1:tags article:2:tags
1) "redis"
```
`redis` is the tag shared between articles 1 and 2, as intended.

```
$ docker exec redis-foundations redis-cli INCR article:1:views
(integer) 1
$ docker exec redis-foundations redis-cli ZINCRBY leaderboard:articles:views 1 article:1
"1"
```
One view event, recorded in two places: a simple counter for "total views on this article," and a sorted-set score for "how this article ranks against every other article."

```
$ docker exec redis-foundations redis-cli LPUSH feed:global "article:1"
(integer) 1
$ docker exec redis-foundations redis-cli LTRIM feed:global 0 19
OK
$ docker exec redis-foundations redis-cli LRANGE feed:global 0 -1
1) "article:1"
```
In a real system this `LPUSH`+`LTRIM` pair runs on every view event, keeping `feed:global` capped at its 20 most recent entries no matter how many views accumulate over time.

```
$ docker exec redis-foundations redis-cli SCAN 0 MATCH "article:*:tags" COUNT 100
0
1) "article:1:tags"
2) "article:2:tags"
3) "article:3:tags"
```
(If your lab environment still has `article:42:tags`/`article:43:tags` left over from Lesson 06's exercise, those will show up here too — same pattern, same database, real leftover state. That's expected, not a bug: `SCAN` finds everything matching the pattern that currently exists.)

```
$ docker exec redis-foundations redis-cli TTL session:demo
(integer) 288
$ docker exec redis-foundations redis-cli PERSIST session:demo
(integer) 1
$ docker exec redis-foundations redis-cli TTL session:demo
(integer) -1
```

```
$ docker exec redis-foundations redis-cli OBJECT ENCODING user:1
"listpack"
$ docker exec redis-foundations redis-cli OBJECT ENCODING article:1:tags
"listpack"
$ docker exec redis-foundations redis-cli OBJECT ENCODING leaderboard:articles:views
"listpack"
$ docker exec redis-foundations redis-cli OBJECT ENCODING feed:global
"listpack"
```
Every structure here lands on `listpack` — the compact, small-collection encoding used across hashes, sets, sorted sets, and lists alike, since none of them holds enough entries yet to cross their respective `*-max-listpack-*` thresholds. This is exactly the kind of intuition Lesson 10 is about: know what makes a structure grow past its compact encoding, so you're not surprised when it happens in production.

```
$ bash verify.sh
PASS: user:1 is a hash
PASS: user:1 has a name field
PASS: session:demo exists
PASS: session:demo was persisted
PASS: article:1:tags is a set
PASS: leaderboard has entries
PASS: feed:global capped at <=20

Results: 7 passed, 0 failed
```
