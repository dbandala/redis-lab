# Solution 08 — TTL and Key Naming

```
$ docker exec redis-foundations redis-cli SET cache:product:9001 "cached-payload"
OK

$ docker exec redis-foundations redis-cli EXPIRE cache:product:9001 120
(integer) 1
$ docker exec redis-foundations redis-cli TTL cache:product:9001
(integer) 120

$ docker exec redis-foundations redis-cli EXPIRE cache:product:9001 30 GT
(integer) 0
$ docker exec redis-foundations redis-cli TTL cache:product:9001
(integer) 119
```
The `EXPIRE ... GT` call returned `0` (rejected) because `30` is not greater than the current TTL — the small drop from `120` to `119` is just a second of wall-clock time passing, not the rejected update taking effect.

```
$ docker exec redis-foundations redis-cli EXPIRE cache:product:9001 300 GT
(integer) 1
$ docker exec redis-foundations redis-cli TTL cache:product:9001
(integer) 300
```
This time it succeeded — `300 > 119`, so `GT` allowed it.

```
$ docker exec redis-foundations redis-cli PERSIST cache:product:9001
(integer) 1
$ docker exec redis-foundations redis-cli TTL cache:product:9001
(integer) -1
```
`-1` means no expiration is set.

```
$ docker exec redis-foundations redis-cli COPY user:1001 user:1001:backup
(integer) 1
$ docker exec redis-foundations redis-cli HGETALL user:1001:backup
1) "name"
2) "Ada"
3) "login_count"
4) "1"
```
(Your own output may also include an `email` field if you run this soon after Lesson 05 — that field carried a 60-second per-field TTL from the `HEXPIRE` exercise and will have expired by the time you reach this lesson.)

7. Example key names for a shopping-cart feature, following `<object-type>:<id>[:<sub-resource>]`:
   - `cart:user:1001` — the cart contents for user 1001
   - `coupon:user:1001:SUMMER25` — a coupon applied to a specific user
   - `checkout:session:abc123` — an in-progress checkout session
