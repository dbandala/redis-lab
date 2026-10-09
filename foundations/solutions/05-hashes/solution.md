# Solution 05 — Hashes

```
$ docker exec redis-foundations redis-cli HSET user:1001 name "Ada" email "ada@example.com" plan "free"
(integer) 3

$ docker exec redis-foundations redis-cli HGETALL user:1001
1) "name"
2) "Ada"
3) "email"
4) "ada@example.com"
5) "plan"
6) "free"

$ docker exec redis-foundations redis-cli HMGET user:1001 name plan
1) "Ada"
2) "free"

$ docker exec redis-foundations redis-cli HINCRBY user:1001 login_count 1
(integer) 1

$ docker exec redis-foundations redis-cli HDEL user:1001 plan
(integer) 1
$ docker exec redis-foundations redis-cli HGETALL user:1001
1) "name"
2) "Ada"
3) "email"
4) "ada@example.com"
5) "login_count"
6) "1"

$ docker exec redis-foundations redis-cli OBJECT ENCODING user:1001
"listpack"

$ docker exec redis-foundations redis-cli HEXPIRE user:1001 60 FIELDS 1 email
1) (integer) 1
$ docker exec redis-foundations redis-cli HTTL user:1001 FIELDS 1 email
1) (integer) 60

$ docker exec redis-foundations redis-cli HTTL user:1001 FIELDS 1 name
1) (integer) -1
```
`-1` means "no TTL set on this field" — exactly what we expect for `name`, which was never given a per-field expiration.
