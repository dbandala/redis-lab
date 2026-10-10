# Lesson 05 — Building a RAG Retrieval Pipeline

## Learning Objectives

By the end of this lesson you can:
- Combine a metadata filter (`TAG`) with a vector `KNN` clause in a single `FT.SEARCH` hybrid query
- Explain why pre-filtering before the vector search — not after — is what makes hybrid search both fast and precise
- Recognize this as the retrieval half of a RAG (Retrieval-Augmented Generation) pipeline: find the right context, *then* hand it to an LLM

## Concept

A RAG backend has two halves: **retrieval** (find the most relevant pieces of text for a question) and **generation** (hand those pieces to an LLM as context so it answers grounded in your data instead of guessing). Redis's job is the first half. This lesson builds a small support knowledge base for Pulse — FAQ-style documents about refunds, accessibility, and parking — and queries it the way a RAG backend's retrieval step would.

Run the seed script to load eight knowledge-base documents and build a hybrid-searchable index in one step:

```
$ python3 exercises/05-building-a-rag-pipeline/seed-vectors.py | docker exec -i redis-modern-data-models redis-cli --no-raw
```

Each document is a JSON record with a `category` tag and a 4-dimensional toy `embedding` (see the seed script's docstring — these are hand-picked to cluster by topic, standing in for real embedding-model output), indexed by:

```
$.title AS title TEXT
$.category AS category TAG
$.text AS text TEXT
$.embedding AS embedding VECTOR HNSW 6 TYPE FLOAT32 DIM 4 DISTANCE_METRIC COSINE
```

Say a user asks: *"I need my money back because the concert got cancelled."* A real pipeline would embed that question with the same model used to embed the documents; here we hand-pick a query vector that sits near the `refunds` cluster, `[0.88, 0.12, 0.12, 0.2]`. A plain KNN query (no filter) already finds the right documents, because the vectors themselves cluster by topic:

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.88, 0.12, 0.12, 0.2))" > refund_query.bin
$ cat refund_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "*=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc1"
3) 1) "score"
   2) "0.000578165054321"
   3) "title"
   4) "How do I get a refund for a cancelled show?"
4) "kb:doc2"
5) 1) "score"
   2) "0.00307679176331"
   3) "title"
   4) "Can I get a refund if I just change my mind?"
```

So why add a filter at all? Because real questions aren't always this clean. Try a deliberately **ambiguous** query vector that sits roughly between clusters, `[0.5, 0.5, 0.3, 0.3]`:

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.5, 0.5, 0.3, 0.3))" > ambiguous_query.bin
$ cat ambiguous_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "*=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc4"
3) 1) "score"
   2) "0.148764014244"
   3) "title"
   4) "Do you provide ASL interpreters?"
4) "kb:doc2"
5) 1) "score"
   2) "0.174726009369"
   3) "title"
   4) "Can I get a refund if I just change my mind?"
```

Unfiltered, that query mixes an **accessibility** document with a **refunds** document — plausible nearest neighbors in raw vector space, but the wrong *pair* if your application already knows (from conversation state, a UI category picker, or an upstream intent classifier) that this question is about accessibility. A **hybrid query** — a `TAG` filter joined to the KNN clause with `=>` — restricts the nearest-neighbor search to the matching subset *before* ranking, instead of ranking everything and hoping the filter lines up after the fact:

```
$ cat ambiguous_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "@category:{accessibility}=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc4"
3) 1) "score"
   2) "0.148764014244"
   3) "title"
   4) "Do you provide ASL interpreters?"
4) "kb:doc3"
5) 1) "score"
   2) "0.19128203392"
   3) "title"
   4) "Requesting a wheelchair-accessible seating area"
```

Same ambiguous query, same index — but `@category:{accessibility}=>[KNN 2 @embedding $BLOB AS score]` now returns two *accessibility* documents, correctly excluding the refunds document that outranked `kb:doc3` in the unfiltered search. This is the retrieval step of a RAG pipeline in its most common real-world shape: narrow by metadata you already trust, then rank by semantic similarity within that narrowed set.

> **Why filter-then-rank beats rank-then-filter.** RediSearch's `field=>[KNN ...]` syntax runs the `TAG`/`NUMERIC` filter first and performs the KNN search only over the documents that already match — both faster (fewer candidates to score) and more correct (the top-k is k *relevant* results, not k globally-similar results you then have to discard down to the relevant ones, possibly ending up with fewer than you wanted).

## Official Docs

- [Hybrid queries](https://redis.io/docs/latest/develop/ai/search-and-query/query/combined/)
- [KNN syntax](https://redis.io/docs/latest/develop/ai/search-and-query/vectors/#knn-vector-search)
- [RAG with Redis](https://redis.io/docs/latest/develop/ai/rag/)

## Exercise

→ [exercises/05-building-a-rag-pipeline/exercise.md](../exercises/05-building-a-rag-pipeline/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU331: Vector Databases" has a module specifically on building RAG retrieval pipelines with hybrid filtering.
