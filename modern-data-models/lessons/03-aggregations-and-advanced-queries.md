# Lesson 03 — Aggregations & Advanced Queries

## Learning Objectives

By the end of this lesson you can:
- Build multi-stage `FT.AGGREGATE` pipelines (`GROUPBY`/`REDUCE`, `APPLY`, `SORTBY`) to answer analytical questions directly in Redis
- Add typo-tolerant autocomplete over a dictionary with `FT.SUGADD`/`FT.SUGGET`
- Explain the difference between `FT.SEARCH` (find matching documents) and `FT.AGGREGATE` (reshape/summarize across documents)

## Concept

`FT.SEARCH` answers "which documents match?" `FT.AGGREGATE` answers a different kind of question — "summarized how, across how many?" — by running a pipeline of stages over the matched documents, the same mental model as a SQL `GROUP BY` or a pandas `groupby().agg()`, but executed server-side over the index.

`GROUPBY` + `REDUCE` groups matching documents by a field and computes an aggregate per group:

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" GROUPBY 1 @city REDUCE COUNT 0 AS num_events REDUCE AVG 1 @price AS avg_price SORTBY 2 @num_events DESC
1) (integer) 2
2) 1) "city"
   2) "Austin"
   3) "num_events"
   4) "3"
   5) "avg_price"
   6) "51.5"
3) 1) "city"
   2) "Denver"
   3) "num_events"
   4) "2"
   5) "avg_price"
   6) "40"
```

`GROUPBY 1 @city` groups by one field; `REDUCE COUNT 0 AS num_events` counts rows per group (`0` = no input args to `COUNT`); `REDUCE AVG 1 @price AS avg_price` averages `price` per group. `SORTBY 2 @num_events DESC` orders the *aggregated* rows (`2` = two tokens follow: the field and its direction).

Aggregation stages only see fields you explicitly `LOAD` or that already came from a prior stage — unlike `FT.SEARCH`, which returns a document's fields by default, `FT.AGGREGATE` starts from an empty row per match. Skipping the `LOAD` is a common first mistake:

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" APPLY "@price > 50" AS is_premium LOAD 1 @name SORTBY 2 @price DESC
(error) SEARCH_PROP_NOT_FOUND Property not loaded nor in pipeline: `price`
```

`APPLY` ran before `price` existed in the pipeline. Loading the fields you need *before* any stage that references them fixes it:

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" LOAD 2 @name @price APPLY "@price > 50" AS is_premium SORTBY 2 @price DESC
1) (integer) 5
2) 1) "name"
   2) "Night Lights Festival"
   3) "price"
   4) "79.5"
   5) "is_premium"
   6) "1"
...
```

`APPLY` computes a derived value per row with an expression language (comparisons, arithmetic, string/date functions) — here, a boolean "is this a premium-priced event" flag computed on the fly, with no schema change needed to add it.

Separately, `FT.SUGADD`/`FT.SUGGET` maintain a dedicated autocomplete dictionary — a different structure from the search index, optimized for prefix lookups as a user types, with an optional popularity score:

```
$ docker exec redis-modern-data-models redis-cli FT.SUGADD autocomplete:events "Night Lights Festival" 5
(integer) 1
$ docker exec redis-modern-data-models redis-cli FT.SUGADD autocomplete:events "Sunset Jazz Night" 3
(integer) 2
$ docker exec redis-modern-data-models redis-cli FT.SUGGET autocomplete:events Ni WITHSCORES
1) "Night Lights Festival"
2) "1.1180340051651"
```

`FUZZY` tolerates a single typo (insertion, deletion, substitution, or transposition costing 2) against the dictionary's entries:

```
$ docker exec redis-modern-data-models redis-cli FT.SUGGET autocomplete:events Nigt FUZZY
1) "Night Lights Festival"
```

`"Nigt"` (missing the `h`) still finds `"Night Lights Festival"` — one edit away. `FT.SUGLEN` reports the dictionary's size, and `FT.INFO` (seen in Lesson 02) reports index-wide stats like `num_docs` and `num_records` for the search index itself — the two are separate structures living under separate keys, so sizing or clearing one never touches the other.

> **When to reach for AGGREGATE.** If the answer is "a list of matching documents," use `FT.SEARCH`. If the answer is "a number, grouped, or a small reshaped table" — events per city, average price per tag, top-N by a computed score — reach for `FT.AGGREGATE`. Doing that grouping in application code would mean pulling every matching document across the network first; `FT.AGGREGATE` does it where the data already lives.

## Official Docs

- [FT.AGGREGATE](https://redis.io/docs/latest/commands/ft.aggregate/)
- [Aggregations](https://redis.io/docs/latest/develop/ai/search-and-query/advanced-concepts/aggregations/)
- [FT.SUGADD](https://redis.io/docs/latest/commands/ft.sugadd/)
- [FT.SUGGET](https://redis.io/docs/latest/commands/ft.sugget/)

## Exercise

→ [exercises/03-aggregations-and-advanced-queries/exercise.md](../exercises/03-aggregations-and-advanced-queries/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU203: Querying, Indexing, and Full-Text Search" covers the aggregation pipeline in depth, including its full function library.
