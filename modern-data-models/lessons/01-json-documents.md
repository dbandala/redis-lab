# Lesson 01 — JSON Documents (RedisJSON)

## Learning Objectives

By the end of this lesson you can:
- Store, read, and partially update a JSON document in Redis using JSONPath, without round-tripping the whole document through your application
- Explain why this module needs no extra image or install step beyond the `redis:8.10.1` container you already have running
- Recognize the running scenario for this module: **Pulse Discover**, a recommendation and search layer built on top of the Pulse ticketing platform from Level 2

## Concept

> **What's new: "Redis Stack" isn't a separate thing anymore.** Through 2024, JSON support, full-text search, and probabilistic data structures shipped as the separately-distributed **Redis Stack** — its own Docker image, bundled as extra modules on top of plain Redis. Since **Redis 8.0** (May 2025), all of that — JSON, the Query Engine (née RediSearch), Time Series, the probabilistic structures, and a new native Vector Sets type — ships *inside* Redis Open Source itself. Run `MODULE LIST` against this lab's `redis:8.10.1` container and you'll see `ReJSON`, `search`, `bf`, `timeseries`, and `vectorset` already loaded — nobody added them, they're compiled into the standard image. Level 3 runs on the exact same `docker-compose.yml` pattern as Level 1 and 2; there's no `redis-stack-server` image to switch to.

Level 2 built Pulse's hot-data layer out of strings, hashes, and sorted sets — fast, but each key held one flat value. **Pulse Discover** needs richer records: an event catalog with nested, variable-shaped data (tags, pricing tiers, venue details) that the application wants to read and patch *in place*, without fetching the whole blob, mutating it in app code, and writing it all back.

`JSON.SET` writes a document at a path (`$` is the document root):

```
$ docker exec redis-modern-data-models redis-cli JSON.SET event:evt100 $ '{"name":"Night Lights Festival","venue":"Riverside Park","city":"Austin","tags":["music","outdoor"],"capacity":5000,"price":79.5,"views":0,"soldOut":false}'
OK
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt100
"{\"name\":\"Night Lights Festival\",\"venue\":\"Riverside Park\",\"city\":\"Austin\",\"tags\":[\"music\",\"outdoor\"],\"capacity\":5000,\"price\":79.5,\"views\":0,\"soldOut\":false}"
```

`JSON.GET` with a **JSONPath** reads just the part you need, returned as a JSON array of matches (one element per matching path):

```
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt100 $.name
"[\"Night Lights Festival\"]"
```

The real win is updating a nested field **atomically**, server-side, without a read-modify-write round trip. `JSON.NUMINCRBY` increments a numeric field in place — same atomicity guarantee as `INCR`, just nested inside a document instead of standing alone as a string key:

```
$ docker exec redis-modern-data-models redis-cli JSON.NUMINCRBY event:evt100 $.views 1
"[1]"
$ docker exec redis-modern-data-models redis-cli JSON.NUMINCRBY event:evt100 $.views 1
"[2]"
```

`JSON.ARRAPPEND` pushes onto a nested array in place:

```
$ docker exec redis-modern-data-models redis-cli JSON.ARRAPPEND event:evt100 $.tags '"family-friendly"'
1) (integer) 3
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt100 $.tags
"[[\"music\",\"outdoor\",\"family-friendly\"]]"
```

`JSON.MERGE` applies an RFC 7396 JSON Merge Patch — set only the fields you name, leave everything else untouched (this is the JSON-document equivalent of `HSET` touching one field without clobbering the rest of a hash):

```
$ docker exec redis-modern-data-models redis-cli JSON.MERGE event:evt100 $ '{"soldOut":true}'
OK
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt100 $.soldOut
"[true]"
```

A few more read-side tools you'll reach for constantly: `JSON.OBJKEYS` lists an object's top-level fields, `JSON.TYPE` reports a path's JSON type, and `JSON.STRLEN` measures a string field's length without fetching it:

```
$ docker exec redis-modern-data-models redis-cli JSON.OBJKEYS event:evt100 $
1) 1) "name"
   2) "venue"
   3) "city"
   4) "tags"
   5) "capacity"
   6) "price"
   7) "views"
   8) "soldOut"
$ docker exec redis-modern-data-models redis-cli JSON.TYPE event:evt100 $.tags
1) "array"
$ docker exec redis-modern-data-models redis-cli JSON.STRLEN event:evt100 $.name
1) (integer) 21
```

The server-level `TYPE` command reports JSON documents as their own type, `ReJSON-RL` — not `string` — even though the document is stored internally in a serialized, parsed-tree form (`OBJECT ENCODING` reports `raw`):

```
$ docker exec redis-modern-data-models redis-cli TYPE event:evt100
ReJSON-RL
```

And `JSON.DEL` removes a path, not just the whole key:

```
$ docker exec redis-modern-data-models redis-cli JSON.DEL event:evt100 $.soldOut
(integer) 1
$ docker exec redis-modern-data-models redis-cli JSON.GET event:evt100
"{\"name\":\"Night Lights Festival\",\"venue\":\"Riverside Park\",\"city\":\"Austin\",\"tags\":[\"music\",\"outdoor\",\"family-friendly\"],\"capacity\":5000,\"price\":79.5,\"views\":2}"
```

> **When to reach for JSON vs. a hash.** A hash is still the right call for a flat record with a fixed, known set of fields (Level 2's `session:tok_*`). Reach for `JSON.SET` when the record is naturally nested or variable-shaped — an event with an open-ended tag list, pricing tiers, or venue sub-object — and you want to patch one nested field atomically instead of re-serializing the whole thing in your application. JSON documents are also the foundation the next two lessons build on: RediSearch indexes JSON fields directly.

## Official Docs

- [JSON.SET](https://redis.io/docs/latest/commands/json.set/)
- [JSON.GET](https://redis.io/docs/latest/commands/json.get/)
- [JSON.NUMINCRBY](https://redis.io/docs/latest/commands/json.numincrby/)
- [JSON.MERGE](https://redis.io/docs/latest/commands/json.merge/)
- [JSONPath syntax](https://redis.io/docs/latest/develop/data-types/json/path/)

## Exercise

→ [exercises/01-json-documents/exercise.md](../exercises/01-json-documents/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU204: Redis Streams" and the JSON module sections of "RU102" cover document modeling with RedisJSON in more depth.
