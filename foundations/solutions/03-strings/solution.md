# Solution 03 — Strings

```
$ docker exec redis-foundations redis-cli SET user:1:name "Ada Lovelace"
OK
$ docker exec redis-foundations redis-cli GET user:1:name
"Ada Lovelace"

$ docker exec redis-foundations redis-cli SET user:1:name "Ada L." XX
OK

$ docker exec redis-foundations redis-cli SET user:2:name "Grace Hopper" NX
OK
$ docker exec redis-foundations redis-cli SET user:2:name "should not overwrite" NX
(nil)
$ docker exec redis-foundations redis-cli GET user:2:name
"Grace Hopper"

$ docker exec redis-foundations redis-cli SET counter:visits 0
OK
$ docker exec redis-foundations redis-cli INCR counter:visits
(integer) 1
$ docker exec redis-foundations redis-cli INCRBY counter:visits 10
(integer) 11
$ docker exec redis-foundations redis-cli OBJECT ENCODING counter:visits
"int"
```
`counter:visits` encodes as `int` because its value (`11`) fits in a 64-bit integer and Redis stores it as a native integer instead of a text string.

```
$ docker exec redis-foundations redis-cli SET session:abc123 "token-data" EX 60
OK
$ docker exec redis-foundations redis-cli TTL session:abc123
(integer) 60
$ docker exec redis-foundations redis-cli SET session:abc123 "updated-token" KEEPTTL
OK
$ docker exec redis-foundations redis-cli TTL session:abc123
(integer) 60
```
The TTL is unchanged (still ~60, minus a second or two of wall-clock time) because `KEEPTTL` was used — a plain `SET` without it would have reset the key to no expiration.

```
$ docker exec redis-foundations redis-cli GETDEL session:abc123
"updated-token"
$ docker exec redis-foundations redis-cli EXISTS session:abc123
(integer) 0
```

```
$ docker exec redis-foundations redis-cli OBJECT ENCODING user:1:name
"embstr"
```
`user:1:name` holds `"Ada L."`, a short (≤ 44 byte) string that hasn't been mutated in place, so Redis uses the compact `embstr` encoding — versus `int` for `counter:visits`, whose value is a plain integer.

```
$ docker exec redis-foundations redis-cli STRLEN user:1:name
(integer) 6
$ docker exec redis-foundations redis-cli APPEND user:1:name " (Countess of Lovelace)"
(integer) 29
$ docker exec redis-foundations redis-cli GET user:1:name
"Ada L. (Countess of Lovelace)"
```
Note: after `APPEND` mutates the string in place, its encoding changes from `embstr` (immutable) to `raw` — `embstr` values are never modified in place, since doing so would require reallocating the header+data block they share.

```
$ docker exec redis-foundations redis-cli MSET a 1 b 2 c 3
OK
$ docker exec redis-foundations redis-cli MGET a b c
1) "1"
2) "2"
3) "3"
```
