# Solution 01 — JSON Documents

```
$ docker exec redis-modern-data-models redis-cli JSON.SET event:evt200 $ '{"name":"Sunset Jazz Night","venue":"Blue Note Hall","city":"Denver","tags":["jazz","indoor"],"capacity":800,"price":45,"views":0,"soldOut":false}'
OK
```
One call writes the whole nested document at the root path (`$`).

```
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt200 $.venue
"[\"Blue Note Hall\"]"
```
`JSON.GET` with a path returns a JSON array of matches — here, one match — rather than fetching and parsing the whole document client-side.

```
$ docker exec redis-modern-data-models redis-cli JSON.NUMINCRBY event:evt200 $.views 1
"[1]"
$ docker exec redis-modern-data-models redis-cli JSON.NUMINCRBY event:evt200 $.views 1
"[2]"
$ docker exec redis-modern-data-models redis-cli JSON.NUMINCRBY event:evt200 $.views 1
"[3]"
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt200 $.views
"[3]"
```
Final value: `3`. `JSON.NUMINCRBY` both applies and returns the new value, so you don't strictly need the trailing `JSON.GET` — it's shown here only to demonstrate reading the field back without mutating it.

```
$ docker exec redis-modern-data-models redis-cli JSON.ARRAPPEND event:evt200 $.tags '"21+"'
1) (integer) 3
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt200 $.tags
"[[\"jazz\",\"indoor\",\"21+\"]]"
```
`JSON.ARRAPPEND` returns the array's new length (`3`); `JSON.GET` confirms the element landed at the end.

```
$ docker exec redis-modern-data-models redis-cli JSON.MERGE event:evt200 $ '{"soldOut":true}'
OK
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt200 $.soldOut
"[true]"
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt200 $.views
"[3]"
```
`JSON.MERGE` is a JSON Merge Patch: only the fields named in the patch (`soldOut`) change. `views` is still `3` — `JSON.MERGE` never touches fields it wasn't told about, which is exactly what makes it safe for partial updates from different parts of an application without a read-modify-write race.

```
$ docker exec redis-modern-data-models redis-cli TYPE event:evt200
ReJSON-RL
$ docker exec redis-modern-data-models redis-cli OBJECT ENCODING event:evt200
"raw"
```
`TYPE` reports `ReJSON-RL` — RedisJSON registers its own Redis type, distinct from `string`, `hash`, etc. `JSON.GET`'s quoted output is just `redis-cli` rendering the RESP bulk-string *reply* of that command; the key's actual stored type is the JSON document type, which is why commands like `JSON.NUMINCRBY` and `JSON.ARRAPPEND` can mutate a nested field in place instead of you having to `GET`, parse, mutate, and `SET` a whole string blob yourself.
