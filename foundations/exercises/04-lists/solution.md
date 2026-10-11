# Solution 04 — Lists

```
$ docker exec redis-foundations redis-cli RPUSH queue:emails "a@x.com" "b@x.com" "c@x.com"
(integer) 3
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "a@x.com"
2) "b@x.com"
3) "c@x.com"

$ docker exec redis-foundations redis-cli LPOP queue:emails
"a@x.com"

$ docker exec redis-foundations redis-cli LPUSH queue:emails "priority@x.com"
(integer) 3
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "priority@x.com"
2) "b@x.com"
3) "c@x.com"
```
The priority item lands at index 0 — `LPUSH` inserts at the left/head end.

```
$ docker exec redis-foundations redis-cli LMOVE queue:emails queue:emails:processed LEFT RIGHT
"priority@x.com"
$ docker exec redis-foundations redis-cli LRANGE queue:emails:processed 0 -1
1) "priority@x.com"
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "b@x.com"
2) "c@x.com"
```

```
$ docker exec redis-foundations redis-cli OBJECT ENCODING queue:emails
"listpack"
$ docker exec redis-foundations redis-cli LLEN queue:emails
(integer) 2
```
`listpack` because the list is small (well under the 128-entry default threshold) — it hasn't been promoted to `quicklist`.

```
$ docker exec redis-foundations redis-cli LINSERT queue:emails BEFORE "b@x.com" "inserted@x.com"
(integer) 3
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "inserted@x.com"
2) "b@x.com"
3) "c@x.com"
```

```
$ docker exec redis-foundations redis-cli LTRIM queue:emails 0 1
OK
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "inserted@x.com"
2) "b@x.com"
```
`"c@x.com"` was discarded — `LTRIM 0 1` keeps only indices 0 and 1.
