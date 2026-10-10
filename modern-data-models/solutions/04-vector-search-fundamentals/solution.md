# Solution 04 — Vector Search Fundamentals

```
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.1 0.9 0.2 0.3 evt400
(integer) 1
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.15 0.95 0.25 0.25 evt600
(integer) 1
$ docker exec redis-modern-data-models redis-cli VCARD vibes:events
(integer) 6
```

```
$ docker exec redis-modern-data-models redis-cli VSIM vibes:events VALUES 4 0.15 0.9 0.25 0.3 WITHSCORES COUNT 2
1) "evt600"
2) "0.9975329549051821"
3) "evt400"
4) "0.997532892273739"
```
`evt600` (the acoustic night, which the query vector is almost identical to) edges out `evt400` (jazz brunch) by a hair — both score above `0.997`, correctly separating these two chill events from the higher-energy ones.

```
$ docker exec redis-modern-data-models redis-cli JSON.SET event:evt600 $ '{"name":"Acoustic Singer-Songwriter Night","venue":"The Parlor","city":"Austin","tags":["acoustic","indoor"],"capacity":200,"price":25,"views":0,"soldOut":false,"vibe":[0.15,0.95,0.25,0.25]}'
OK
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events_vec "@name:Acoustic" RETURN 1 name
1) (integer) 1
2) "event:evt600"
3) 1) "name"
   2) "Acoustic Singer-Songwriter Night"
```
Writing the JSON document is enough — `idx:events_vec` picks it up automatically because the key matches the `event:` prefix the index was created on, same as Lessons 02-03.

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.15, 0.9, 0.25, 0.3))" > query_vec2.bin
$ cat query_vec2.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:events_vec "*=>[KNN 2 @vibe \$BLOB AS score]" DIALECT 2 RETURN 2 name score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "event:evt600"
3) 1) "score"
   2) "0.00194776058197"
   3) "name"
   4) "Acoustic Singer-Songwriter Night"
4) "event:evt400"
5) 1) "score"
   2) "0.00242078304291"
   3) "name"
   4) "Downtown Jazz Brunch"
```
Same order as step 2: `evt600` first, `evt400` second. Two different data structures (a Vector Set vs. a RediSearch vector field), two different scoring conventions (cosine similarity vs. cosine distance), same nearest-neighbor answer — because both are indexing the same underlying vectors with the same distance metric.

```
$ docker exec redis-modern-data-models redis-cli VREM vibes:events evt600
(integer) 1
$ docker exec redis-modern-data-models redis-cli VCARD vibes:events
(integer) 5
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events_vec "@name:Acoustic" RETURN 1 name
1) (integer) 1
2) "event:evt600"
3) 1) "name"
   2) "Acoustic Singer-Songwriter Night"
```
`event:evt600` still shows up in `idx:events_vec` after being removed from `vibes:events` entirely. That confirms the two are fully independent structures: a Vector Set (`vibes:events`) stores its own copy of vectors under member names with no link back to a Redis key, while the RediSearch vector field reads straight from the `event:evt600` JSON document. Deleting one has zero effect on the other — they'd both need to be kept in sync by your application if you used both over the same data, which is itself a reason to prefer one approach per use case rather than running both side by side in production.
