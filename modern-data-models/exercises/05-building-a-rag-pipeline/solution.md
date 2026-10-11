# Solution 05 — Building a RAG Retrieval Pipeline

```
$ docker exec redis-modern-data-models redis-cli JSON.SET kb:doc9 $ '{"title":"Are accessible parking spaces available?","category":"parking","text":"Yes, accessible parking spaces are available near the main entrance; mention it when purchasing your parking pass.","embedding":[0.2,0.3,0.88,0.15]}'
OK
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:kb "@category:{parking}" RETURN 1 title
1) (integer) 3
2) "kb:doc6"
3) 1) "title"
   2) "Is parking included with my ticket?"
4) "kb:doc9"
5) 1) "title"
   2) "Are accessible parking spaces available?"
6) "kb:doc5"
7) 1) "title"
   2) "Where can I park near the venue?"
```
`kb:doc9` is indexed the instant it's written — three `parking` documents now, no separate index step.

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.266, 0.228, 0.57, 0.53))" > mixed_query.bin
$ cat mixed_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "*=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc6"
3) 1) "score"
   2) "0.137073874474"
   3) "title"
   4) "Is parking included with my ticket?"
4) "kb:doc8"
5) 1) "score"
   2) "0.137702703476"
   3) "title"
   4) "What items are prohibited inside the venue?"
```
Unfiltered, the top 2 is genuinely mixed: one `parking` document and one `general` document, with near-identical distance scores (`0.1371` vs. `0.1377`) — exactly the ambiguous case a hybrid filter is meant to resolve.

```
$ cat mixed_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "@category:{general}=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc8"
3) 1) "title"
   2) "What items are prohibited inside the venue?"
4) "kb:doc7"
5) 1) "title"
   2) "How early should I arrive before the show?"
```
With `@category:{general}` pre-filtering, both results are `general` documents — `kb:doc6` (the nearest neighbor overall) is correctly excluded because it isn't in the filtered subset.

```
$ cat mixed_query.bin | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:kb "@category:{parking}=>[KNN 2 @embedding \$BLOB AS score]" DIALECT 2 RETURN 2 title score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "kb:doc6"
3) 1) "title"
   2) "Is parking included with my ticket?"
4) "kb:doc9"
5) 1) "title"
   2) "Are accessible parking spaces available?"
```
With `@category:{parking}`, both results flip to `parking` documents instead — same query vector, same index, a completely different (and in this scenario, equally "correct") pair of results depending entirely on which filter the application chose.

For the two-topic question ("doors open" + "parking"), a **single** hybrid query with one category filter answers only half of it well — whichever category you pick, you silently drop the other topic's context. In a real RAG backend, the usual fix is to not force one filter: either (a) run the retrieval step twice, once per detected topic/category, and concatenate both result sets into the LLM's context, or (b) skip the category filter for genuinely multi-topic questions and fall back to a wider unfiltered KNN with a larger `COUNT`, accepting lower precision per topic in exchange for coverage across topics. Which one a production system picks usually depends on whether an upstream step (intent classification, a UI category picker, conversation state) can reliably split the question into single-topic sub-queries before retrieval — the same tension between precision and recall that this exercise's mixed-vector example surfaced directly.
