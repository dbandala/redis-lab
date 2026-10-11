# Solution — Pulse Discover

```
$ python3 seed-events.py | docker exec -i redis-modern-data-models redis-cli --no-raw
OK
...
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:discover_events "*" LIMIT 0 0
6
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:discover_kb "*" LIMIT 0 0
9
```
One script, two JSON collections, two hybrid-searchable indexes — 6 events and 9 support docs, confirmed indexed.

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.85, 0.15, 0.75, 0.75))" | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:discover_events "@city:{Austin}=>[KNN 2 @vibe \$BLOB AS score]" DIALECT 2 RETURN 2 name score SORTBY score PARAMS 2 BLOB
1) (integer) 2
2) "discover:event:d1"
3) 1) "score" 2) "0.00239902734756" 3) "name" 4) "Night Lights Festival"
4) "discover:event:d3"
5) 1) "score" 2) "0.00254344940186" 3) "name" 4) "Indie Rock Rally"
```
The `@city:{Austin}` tag filter narrows the candidate pool before the KNN ranks within it — `discover:event:d1` ("Night Lights Festival") comes out first, the closest match to a high-energy query vector among Austin-only events.

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:discover_events "*" GROUPBY 1 @city REDUCE COUNT 0 AS num_events REDUCE AVG 1 @price AS avg_price SORTBY 2 @num_events DESC
1) (integer) 2
2) 1) "city" 2) "Austin" 3) "num_events" 4) "4" 5) "avg_price" 6) "44.875"
3) 1) "city" 2) "Denver" 3) "num_events" 4) "2" 5) "avg_price" 6) "40"
```
Austin has more events in the catalog (4 vs. 2) with a slightly higher average price (`44.875` vs. `40`).

```
$ python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', 0.88, 0.12, 0.12, 0.2))" | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH idx:discover_kb "@category:{refunds}=>[KNN 1 @embedding \$BLOB AS score]" DIALECT 2 RETURN 1 title PARAMS 2 BLOB
1) (integer) 1
2) "discover:kb:k1"
3) 1) "title" 2) "How do I get a refund for a cancelled show?"
```
Exactly one result — the `@category:{refunds}` filter plus `KNN 1` means the RAG retrieval step hands the (hypothetical) LLM exactly the one FAQ answer most relevant to a cancellation-refund question.

```
$ docker exec redis-modern-data-models redis-cli XGROUP CREATE stream:pulse:discover:activity grp:discover:analytics $ MKSTREAM
OK
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:discover:activity * event d1 action view user u1
"1791591574628-0"
... (4 more XADDs)
$ docker exec redis-modern-data-models redis-cli XREADGROUP GROUP grp:discover:analytics worker-1 COUNT 5 STREAMS stream:pulse:discover:activity >
1) 1) "stream:pulse:discover:activity"
   2) (5 entries, all now pending for worker-1)
```

```
$ docker exec redis-modern-data-models redis-cli XACK stream:pulse:discover:activity grp:discover:analytics 1791591574628-0 1791591574703-0 1791591574764-0
(integer) 3
$ docker exec redis-modern-data-models redis-cli XAUTOCLAIM stream:pulse:discover:activity grp:discover:analytics worker-2 0 0
1) "0-0"
2) (the 2 still-pending entries, now owned by worker-2)
3) (empty array)
$ docker exec redis-modern-data-models redis-cli XACK stream:pulse:discover:activity grp:discover:analytics 1791591574820-0 1791591574886-0
(integer) 2
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:discover:activity grp:discover:analytics
1) (integer) 0
2) (nil)
3) (nil)
4) (nil)
```
Five entries read, five acknowledged (three directly, two recovered via `XAUTOCLAIM` after a simulated handoff), zero stuck — the same at-least-once, nothing-lost guarantee from Lesson 07 applied to a realistic "analytics worker crashed mid-batch" scenario.

```
$ docker exec redis-modern-data-models redis-cli BF.RESERVE webhooks:seen:discover 0.01 1000
OK
$ docker exec redis-modern-data-models redis-cli BF.ADD webhooks:seen:discover whk_launch_01
(integer) 1
$ docker exec redis-modern-data-models redis-cli BF.ADD webhooks:seen:discover whk_launch_01
(integer) 0
```
The second `BF.ADD` returns `0` — "already seen" — which is precisely how a webhook handler decides to acknowledge a retried delivery without re-processing it.

```
$ docker exec redis-modern-data-models redis-cli CF.RESERVE resale:listed:discover 500
OK
$ docker exec redis-modern-data-models redis-cli CF.ADDNX resale:listed:discover TCK-7001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.ADDNX resale:listed:discover TCK-7002
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.ADDNX resale:listed:discover TCK-7001
(integer) 0
$ docker exec redis-modern-data-models redis-cli CF.DEL resale:listed:discover TCK-7001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.EXISTS resale:listed:discover TCK-7001
(integer) 0
$ docker exec redis-modern-data-models redis-cli CF.EXISTS resale:listed:discover TCK-7002
(integer) 1
```
`TCK-7001`'s duplicate listing attempt was rejected (`0`), and after its listing was cancelled, `CF.DEL` removed it cleanly while leaving `TCK-7002` untouched — the deletion a Bloom filter could never have supported (Lesson 08).

```
$ docker exec redis-modern-data-models redis-cli TOPK.RESERVE trending:events:discover 3 50 5 0.9
OK
$ docker exec redis-modern-data-models redis-cli TOPK.ADD trending:events:discover d1 d1 d1 d3 d5 d5 d5 d5 d2
(12 nils, as expected from Lesson 09's admission rules)
$ docker exec redis-modern-data-models redis-cli TOPK.LIST trending:events:discover WITHCOUNT
1) "d5" 2) (integer) 4
3) "d1" 4) (integer) 3
5) "d2" 6) (integer) 1
```
`d5` (the Lantern Night Market) tops the trending list with 4 simulated views/purchases — the homepage widget's data source, maintained without a sorted set growing unbounded as new event IDs stream through.

```
$ docker exec redis-modern-data-models redis-cli CMS.INITBYDIM search:queries:discover 2000 7
OK
$ docker exec redis-modern-data-models redis-cli CMS.INCRBY search:queries:discover "jazz night" 5 "rock" 2
1) (integer) 5
2) (integer) 2
$ docker exec redis-modern-data-models redis-cli CMS.QUERY search:queries:discover "jazz night" "rock"
1) (integer) 5
2) (integer) 2
```
Search-term frequency tracked in fixed memory, regardless of how many distinct terms Pulse's users ever type into the search box.

```
$ bash verify.sh
PASS: idx:discover_events indexes all 6 catalog events
PASS: idx:discover_kb indexes all 9 support docs
PASS: hybrid rec query returns the high-energy Austin event
PASS: support KB hybrid query answers the refund question
PASS: activity stream has at least 5 entries
PASS: consumer group has zero pending entries
PASS: webhook retry is detected by the Bloom filter
PASS: TCK-7001 was unlisted after the refund
PASS: TCK-7002 is still listed
PASS: trending-now surfaces d5 as the top event
PASS: search-analytics CMS tracked 'jazz night' frequency

Results: 11 passed, 0 failed
```

**Why filter-then-rank, not rank-then-filter (the rubric's discussion point):** both hybrid queries in this capstone (`@city:{Austin}=>[KNN ...]` and `@category:{refunds}=>[KNN ...]`) apply their `TAG` filter *before* scoring vector distance, exactly as Lesson 05 covered. Running the KNN search across the whole catalog or whole knowledge base first and filtering the results afterward risks two failures a production recommendation or RAG system can't afford: the top-k could come back entirely from the wrong city (or the wrong support category) if those happen to be closer in vector space, forcing the application to either backfill with a second query or return fewer results than requested — and it wastes work scoring documents you were always going to discard. Pre-filtering guarantees both correctness (every result actually satisfies the business constraint) and efficiency (the KNN search only ever runs over the subset that could possibly matter).
