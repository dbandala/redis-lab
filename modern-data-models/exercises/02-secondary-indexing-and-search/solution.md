# Solution 02 — Secondary Indexing & Full-Text Search

```
$ docker exec redis-modern-data-models redis-cli JSON.SET event:evt500 $ '{"name":"Lantern Night Market","venue":"Fairgrounds","city":"Austin","tags":["market","family-friendly","outdoor"],"capacity":10000,"price":15,"views":0,"soldOut":false}'
OK
```

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@city:{Austin}" RETURN 1 name
1) (integer) 3
2) "event:evt300"
3) 1) "name"
   2) "Indie Rock Rally"
4) "event:evt100"
5) 1) "name"
   2) "Night Lights Festival"
6) "event:evt500"
7) 1) "name"
   2) "Lantern Night Market"
```
Three Austin events now, including the one just written — no `FT.CREATE` or reindex call was needed. RediSearch registers itself on the `event:` key prefix once, at `FT.CREATE` time, and from then on every write to a matching key updates the index as part of that write, the same way a database updates its indexes on `INSERT` without a separate step.

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "Market" RETURN 1 name
1) (integer) 1
2) "event:evt500"
3) 1) "name"
   2) "Lantern Night Market"
```
`event:evt500` matched because `market` is a token in its `name` field — a `TEXT` field, tokenized and stemmed, so this is a relevance-scored text match, not an exact-string filter.

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@capacity:[(3000 +inf]" RETURN 2 name capacity
1) (integer) 2
2) "event:evt100"
3) 1) "name"
   2) "Night Lights Festival"
   3) "capacity"
   4) "5000"
4) "event:evt500"
5) 1) "name"
   2) "Lantern Night Market"
   3) "capacity"
   4) "10000"
```
`(3000` makes the lower bound exclusive, so `evt300` (`capacity` exactly `3000`) is correctly left out — only `evt100` (5000) and `evt500` (10000) qualify.

```
$ docker exec redis-modern-data-models redis-cli FT.SEARCH idx:events "@city:{Austin} Night" RETURN 1 name
1) (integer) 2
2) "event:evt100"
3) 1) "name"
   2) "Night Lights Festival"
4) "event:evt500"
5) 1) "name"
   2) "Lantern Night Market"
```
Listing a `TAG` filter and a bare text term together combines them with an implicit `AND`: both results are in Austin *and* have "Night" in their name.

```
$ docker exec redis-modern-data-models redis-cli FT.EXPLAIN idx:events "@city:{Austin} Night"
"INTERSECT {\n  TAG:@city {\n    austin\n  }\n  UNION {\n    night\n    +night(expanded)\n  }\n}\n"
```
The outer `INTERSECT` is the `AND` between the two clauses. `TAG:@city { austin }` is the exact tag filter from step 5. The inner `UNION { night / +night(expanded) }` is the text match — RediSearch expands `Night` to also match its stemmed form, which is why a single text term shows up as a small union rather than one bare token.
