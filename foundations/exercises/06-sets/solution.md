# Solution 06 — Sets

```
$ docker exec redis-foundations redis-cli SADD article:42:tags "redis" "database" "nosql"
(integer) 3
$ docker exec redis-foundations redis-cli SADD article:43:tags "redis" "cache" "performance"
(integer) 3

$ docker exec redis-foundations redis-cli SMEMBERS article:42:tags
1) "redis"
2) "database"
3) "nosql"
$ docker exec redis-foundations redis-cli SISMEMBER article:42:tags "redis"
(integer) 1
$ docker exec redis-foundations redis-cli SISMEMBER article:42:tags "postgres"
(integer) 0

$ docker exec redis-foundations redis-cli SINTER article:42:tags article:43:tags
1) "redis"
$ docker exec redis-foundations redis-cli SUNION article:42:tags article:43:tags
1) "nosql"
2) "database"
3) "performance"
4) "redis"
5) "cache"
$ docker exec redis-foundations redis-cli SDIFF article:42:tags article:43:tags
1) "nosql"
2) "database"
```
(Set ordering is implementation-defined — don't rely on a specific order back from Redis for any of these commands.)

```
$ docker exec redis-foundations redis-cli SCARD article:42:tags
(integer) 3
$ docker exec redis-foundations redis-cli OBJECT ENCODING article:42:tags
"listpack"

$ docker exec redis-foundations redis-cli SADD numbers:test 1 2 3 4 5
(integer) 5
$ docker exec redis-foundations redis-cli OBJECT ENCODING numbers:test
"intset"
```
`numbers:test` gets the `intset` encoding — every member is a small integer, so Redis stores them as a compact sorted integer array. `article:42:tags` gets `listpack` instead, because its members are strings, not integers — `intset` is reserved specifically for all-integer sets.
