# Lesson 04 — Vector Search Fundamentals

## Learning Objectives

By the end of this lesson you can:
- Store embedding vectors and run k-nearest-neighbor (KNN) similarity queries using Redis's native **Vector Sets** (`VADD`/`VSIM`)
- Store vectors as a field in a RediSearch index (`VECTOR` field in `FT.CREATE`) and run the same kind of KNN query through `FT.SEARCH`
- Explain the tradeoff between the two approaches, and what `HNSW` vs. `FLAT` and a distance metric actually control

## Concept

"Similarity search" means: given a vector, find the *k* vectors closest to it by some distance metric — not an exact match, a *nearest-neighbor* match. This is the mechanism behind "events like this one," semantic search, and RAG retrieval. Redis 8 ships **two** ways to do this, and this lesson covers both so you can tell them apart.

> **A note on the vectors used here.** Real embeddings come from a model (an LLM embedding API, `sentence-transformers`, etc.) and typically have hundreds of dimensions. To keep this lab dependency-free — no API keys, no ML library install — we use small, hand-picked 4-dimensional "vibe" vectors per event: `[energy, acoustic, danceability, loudness]`, each roughly `0`-`1`. The *mechanics* you're learning (schema, KNN syntax, HNSW vs. FLAT, distance metrics) are identical regardless of where the numbers came from or how many dimensions they have.

### Option 1: native Vector Sets (`VADD`/`VSIM`)

Redis 8 added **Vector Sets**, a dedicated data type for similarity search — no index to create, no schema, just add vectors to a set and query it:

```
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.9 0.1 0.8 0.7 evt100
(integer) 1
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.2 0.9 0.3 0.4 evt200
(integer) 1
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.7 0.2 0.6 0.6 evt300
(integer) 1
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.1 0.9 0.2 0.3 evt400
(integer) 1
$ docker exec redis-modern-data-models redis-cli VADD vibes:events VALUES 4 0.8 0.3 0.9 0.8 evt500
(integer) 1
```

`VALUES 4 ...` means "4 floats follow"; the trailing token (`evt100`) is the member name — Vector Sets attach vectors to arbitrary member names, not necessarily a Redis key. `VCARD`/`VDIM` report the set's size and dimensionality:

```
$ docker exec redis-modern-data-models redis-cli VCARD vibes:events
(integer) 5
$ docker exec redis-modern-data-models redis-cli VDIM vibes:events
(integer) 4
```

`VSIM` finds the nearest members to a query vector, closest first, with `WITHSCORES` showing cosine similarity (`1.0` = identical direction):

```
$ docker exec redis-modern-data-models redis-cli VSIM vibes:events VALUES 4 0.85 0.15 0.75 0.75 WITHSCORES COUNT 3
1) "evt100"
2) "0.9990070019848645"
3) "evt300"
4) "0.9987037312239408"
5) "evt500"
6) "0.9951354316435754"
```

Querying `[0.85, 0.15, 0.75, 0.75]` (high energy, low acoustic, danceable, loud) correctly surfaces the three highest-energy events (`evt100` the festival, `evt300` the rock show, `evt500` the market) over the two chiller jazz events. `VSIM` can also query "find things like this *existing* member" with `ELE` instead of a raw vector — the basis of "more like this":

```
$ docker exec redis-modern-data-models redis-cli VSIM vibes:events ELE evt200 WITHSCORES COUNT 3
1) "evt200"
2) "0.9989651440409943"
3) "evt400"
4) "0.9934941600076854"
5) "evt500"
6) "0.8275770097970963"
```

Querying by `evt200` (the chill jazz night) correctly ranks `evt400` (the other jazz event) second, after itself. `VREM` removes a member:

```
$ docker exec redis-modern-data-models redis-cli VREM vibes:events evt400
(integer) 1
$ docker exec redis-modern-data-models redis-cli VCARD vibes:events
(integer) 4
```

Vector Sets build an `HNSW` graph internally and automatically — there's no index-type choice to make, which is exactly the appeal: minimal API, good default performance, integrated with normal Redis persistence and eviction.

### Option 2: a `VECTOR` field inside a RediSearch index

The alternative is declaring a `VECTOR` field in `FT.CREATE`, the same schema mechanism Lessons 02-03 used for `TEXT`/`TAG`/`NUMERIC` fields — the vector becomes just another attribute of an indexed JSON document, queryable *together* with your other fields (that combination is Lesson 05's hybrid search):

```
$ docker exec redis-modern-data-models redis-cli JSON.SET event:evt100 $.vibe '[0.9,0.1,0.8,0.7]'
OK
$ docker exec redis-modern-data-models redis-cli FT.CREATE idx:events_vec ON JSON PREFIX 1 event: SCHEMA $.name AS name TEXT $.vibe AS vibe VECTOR HNSW 6 TYPE FLOAT32 DIM 4 DISTANCE_METRIC COSINE
OK
```

`HNSW 6` means "HNSW algorithm, 6 construction arguments follow" (`TYPE`, `DIM`, `DISTANCE_METRIC`, and their values). `FLAT` is the other algorithm choice — a brute-force exact scan instead of an approximate graph:

| | `HNSW` | `FLAT` |
|---|---|---|
| Search | Approximate nearest-neighbor (graph-based) | Exact (scans every vector) |
| Speed at scale | Sub-linear, fast even at millions of vectors | Linear in collection size |
| Accuracy | Approximate — can (rarely) miss a true nearest neighbor | Always exact |
| Use when | Production scale, latency matters | Small collections, or you need guaranteed-exact results |

RediSearch's `FT.SEARCH` KNN syntax requires the query vector as a packed binary blob (float32, little-endian) passed as a query parameter — this is the one place a one-line Python snippet earns its keep, since `redis-cli` has no native way to type raw bytes:

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.85, 0.15, 0.75, 0.75))" > query_vec.bin
$ cat query_vec.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:events_vec "*=>[KNN 3 @vibe \$BLOB AS score]" DIALECT 2 RETURN 2 name score SORTBY score PARAMS 2 BLOB
1) (integer) 3
2) "event:evt100"
3) 1) "score"
   2) "0.00239902734756"
   3) "name"
   4) "Night Lights Festival"
4) "event:evt300"
5) 1) "score"
   2) "0.00254344940186"
   3) "name"
   4) "Indie Rock Rally"
6) "event:evt500"
...
```

`redis-cli -x` reads the last argument from stdin — here, the packed vector bytes — so the Python one-liner's *only* job is byte-packing, not embedding generation. `score` is a **distance** (lower = more similar) rather than `VSIM`'s similarity score, but notice the result order is identical to the native Vector Set query above: `evt100`, `evt300`, `evt500` — same vectors, same answer, two different APIs.

> **Which one should you reach for?** Vector Sets (`VADD`/`VSIM`) are the simpler, newer, lower-ceremony option — no index, no schema, built-in `HNSW`. A RediSearch `VECTOR` field is the better choice the moment you need to combine vector similarity with other filters (tag, numeric, text) in one query, or need `FLAT`'s exact search, or are already indexing the same documents for text/tag/numeric search anyway. Lesson 05 builds exactly that combined case.

## Official Docs

- [Vector sets](https://redis.io/docs/latest/develop/data-types/vector-sets/)
- [VADD](https://redis.io/docs/latest/commands/vadd/)
- [VSIM](https://redis.io/docs/latest/commands/vsim/)
- [Vectors (RediSearch field type)](https://redis.io/docs/latest/develop/ai/search-and-query/vectors/)
- [FT.CREATE](https://redis.io/docs/latest/commands/ft.create/)

## Exercise

→ [exercises/04-vector-search-fundamentals/exercise.md](../exercises/04-vector-search-fundamentals/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU331: Vector Databases" covers both Vector Sets and RediSearch vector fields in depth, including quantization and scaling considerations.
