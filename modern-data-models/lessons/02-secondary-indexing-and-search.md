# Lesson 02 — Secondary Indexing & Full-Text Search (RediSearch)

## Learning Objectives

By the end of this lesson you can:
- Build a secondary index over a collection of JSON documents with `FT.CREATE`, mapping JSONPaths to typed, queryable fields
- Write `FT.SEARCH` queries that combine full-text matching, tag filters, and numeric ranges
- Explain why new documents matching the index's key prefix get indexed automatically, with no extra "reindex" step

## Concept

Lesson 01 gave Pulse Discover a JSON catalog, one event per key. But "find every event in Austin under $70" or "find events whose name mentions 'jazz'" isn't something plain `JSON.GET` can answer — you'd have to `SCAN` every `event:*` key and filter in application code, which is exactly the anti-pattern Level 1 Lesson 09 warned about. **RediSearch** (the Query Engine inside Redis 8) builds a real secondary index over a set of keys, so queries like these run server-side against an inverted index instead of a full key scan.

`FT.CREATE` declares an index: which keys to cover (by key-prefix), and which JSONPaths map to which typed, searchable fields:

```
$ docker exec redis-modern-data-models redis-cli FT.CREATE idx:events ON JSON PREFIX 1 event: SCHEMA $.name AS name TEXT $.city AS city TAG $.tags[*] AS tags TAG $.price AS price NUMERIC $.capacity AS capacity NUMERIC
OK
```

- `ON JSON PREFIX 1 event:` — index every key starting with `event:`, parsed as JSON (an `ON HASH` variant exists for hash-shaped data instead).
- `TEXT` fields (`name`) are tokenized and stemmed for natural-language search.
- `TAG` fields (`city`, and `tags[*]` pulling every element of a JSON array into the same tag field) are exact-match, comma-separated categorical values — not tokenized like `TEXT`.
- `NUMERIC` fields (`price`, `capacity`) support range queries.

The instant you create the index, RediSearch scans and indexes every existing `event:*` key — and from then on, indexing is automatic: any `JSON.SET`/`JSON.MERGE` on a matching key updates the index with no separate "reindex" call, the same way a database updates its B-tree the moment you insert a row.

With four events loaded (`evt100` Austin/music/$79.50, `evt200` Denver/jazz/$45, `evt300` Austin/rock/$60, `evt400` Denver/jazz/$35), a plain `FT.SEARCH` does full-text matching against `TEXT` fields:

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events festival
1) (integer) 1
2) "event:evt100"
3) 1) "$"
   2) "{\"name\":\"Night Lights Festival\",...}"
```

`@field:{value}` filters a `TAG` field exactly — no stemming, no partial match:

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@city:{Austin}" RETURN 2 name city
1) (integer) 2
2) "event:evt300"
3) 1) "name"
   2) "Indie Rock Rally"
   3) "city"
   4) "Austin"
4) "event:evt100"
5) 1) "name"
   2) "Night Lights Festival"
   3) "city"
   4) "Austin"
```

`RETURN n field [field ...]` limits the reply to named fields instead of the whole document — the search-engine equivalent of a SQL `SELECT` column list. The same `@tags[*] AS tags TAG` mapping means every tag on every event is independently matchable:

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@tags:{jazz}" RETURN 2 name tags
1) (integer) 2
2) "event:evt400"
3) 1) "name"
   2) "Downtown Jazz Brunch"
   3) "tags"
   4) "jazz"
4) "event:evt200"
5) 1) "name"
   2) "Sunset Jazz Night"
   3) "tags"
   4) "jazz"
```

`@field:[min max]` runs a numeric range query, and queries combine with implicit `AND` by just listing clauses:

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@price:[40 80]" RETURN 2 name price
1) (integer) 3
...
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@city:{Denver} @price:[0 40]" RETURN 2 name price
1) (integer) 1
2) "event:evt400"
3) 1) "name"
   2) "Downtown Jazz Brunch"
   3) "price"
   4) "35"
```

`SORTBY` orders results by any field that's indexed (no separate sort index needed for fields you already search on):

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "*" SORTBY price ASC RETURN 2 name price
1) (integer) 4
2) "event:evt400"
3) 1) "price"
   2) "35"
   3) "name"
   4) "Downtown Jazz Brunch"
...
```

`FT.EXPLAIN` shows the query plan RediSearch actually runs — useful for understanding how a multi-clause query is combined (here, an `INTERSECT` of a `TAG` lookup and a `NUMERIC` range):

```
$ docker exec redis-modern-data-models redis-cli FT.EXPLAIN idx:events "@city:{Austin} @price:[0 70]"
"INTERSECT {\n  TAG:@city {\n    austin\n  }\n  NUMERIC {0.000000 <= @price <= 70.000000}\n}\n"
```

> **TAG vs. TEXT, concretely.** `city TAG` matches `{Austin}` exactly, case-insensitively, with no partial matching or relevance scoring — right for categorical filters. `name TEXT` tokenizes into words, stems them, and scores matches by relevance — right for "search this field like a person searching a search engine." Modeling `city` as `TEXT` would make `@city:Austin` behave like free-text search (fuzzy, scored) instead of a precise filter; modeling `name` as `TAG` would require matching the *entire* field value verbatim. Pick the field type by how you intend to query it, not by what the underlying JSON type happens to be.

## Official Docs

- [FT.CREATE](https://redis.io/docs/latest/commands/ft.create/)
- [FT.SEARCH](https://redis.io/docs/latest/commands/ft.search/)
- [FT.EXPLAIN](https://redis.io/docs/latest/commands/ft.explain/)
- [Query syntax](https://redis.io/docs/latest/develop/ai/search-and-query/query/)
- [Indexing JSON documents](https://redis.io/docs/latest/develop/ai/search-and-query/indexing/)

## Exercise

→ [exercises/02-secondary-indexing-and-search/exercise.md](../exercises/02-secondary-indexing-and-search/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU203: Querying, Indexing, and Full-Text Search" is built entirely around this engine.
