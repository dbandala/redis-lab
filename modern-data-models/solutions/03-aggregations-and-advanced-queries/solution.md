# Solution 03 — Aggregations & Advanced Queries

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" GROUPBY 1 @tags REDUCE COUNT 0 AS num_events SORTBY 4 @num_events DESC @tags ASC
1) (integer) 4
2) 1) "tags"
   2) "jazz"
   3) "num_events"
   4) "2"
3) 1) "tags"
   2) "market"
   3) "num_events"
   4) "1"
4) 1) "tags"
   2) "music"
   3) "num_events"
   4) "1"
5) 1) "tags"
   2) "rock"
   3) "num_events"
   4) "1"
```
`jazz` has the most events (`2`) — `evt200` and `evt400` both carry it. `evt200` also carries `21+`, but that tag only matches one event so it ties at the bottom with the others and doesn't change `jazz`'s count; a `GROUPBY` on a multi-value `TAG` field counts one group membership per value per document, not per document.

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" GROUPBY 1 @city REDUCE MAX 1 @capacity AS max_capacity SORTBY 2 @max_capacity DESC
1) (integer) 2
2) 1) "city"
   2) "Austin"
   3) "max_capacity"
   4) "10000"
3) 1) "city"
   2) "Denver"
   3) "max_capacity"
   4) "800"
```
Austin's largest venue (`evt500`, capacity `10000`) outsizes Denver's largest (`evt200`, capacity `800`) by more than 12x.

```
$ docker exec redis-modern-data-models redis-cli FT.AGGREGATE idx:events "*" LOAD 3 @name @price @capacity APPLY "@price/@capacity*1000" AS price_per_1000_seats SORTBY 2 @price_per_1000_seats DESC
1) (integer) 5
2) 1) "name"
   2) "Downtown Jazz Brunch"
   ...
   7) "price_per_1000_seats"
   8) "233.333333333"
...
6) 1) "name"
   2) "Lantern Night Market"
   ...
   7) "price_per_1000_seats"
   8) "1.5"
```
`"Downtown Jazz Brunch"` has the highest price-per-1000-seats (`233.3`) — a small, pricier venue. `"Lantern Night Market"` has the lowest (`1.5`) — a huge, cheap venue. Neither ranking is visible from `price` or `capacity` alone; it only exists once `APPLY` computes it.

```
$ docker exec redis-modern-data-models redis-cli FT.SUGADD autocomplete:events "Lantern Night Market" 2
(integer) 5
$ docker exec redis-modern-data-models redis-cli FT.SUGLEN autocomplete:events
(integer) 5
$ docker exec redis-modern-data-models redis-cli FT.SUGGET autocomplete:events La
1) "Lantern Night Market"
```
Five entries total; `La` is an unambiguous prefix match.

```
$ docker exec redis-modern-data-models redis-cli FT.SUGDEL autocomplete:events "Downtown Jazz Brunch"
(integer) 1
$ docker exec redis-modern-data-models redis-cli FT.SUGLEN autocomplete:events
(integer) 4
```
`FT.SUGDEL` returns `1` (one entry removed), and `FT.SUGLEN` drops from `5` to `4` — confirming the dictionary is a separate, independently-managed structure from the `idx:events` search index (deleting a suggestion never touches the indexed JSON documents or vice versa).
