# Solution 09 — Top-K & Count-Min Sketch

```
$ docker exec redis-modern-data-models redis-cli TOPK.RESERVE trending:events:practice 3 50 5 0.9
OK
$ docker exec redis-modern-data-models redis-cli TOPK.ADD trending:events:practice evt_a evt_a evt_a evt_a evt_a evt_b evt_b evt_c evt_c evt_c evt_c evt_d
 1) (nil)
 2) (nil)
 3) (nil)
 4) (nil)
 5) (nil)
 6) (nil)
 7) (nil)
 8) (nil)
 9) (nil)
10) (nil)
11) (nil)
12) (nil)
```
All 12 replies are `nil` — including the last one, for `evt_d`. That's notable: `nil` doesn't only mean "there was still room, nothing had to be evicted" (true for the first few adds, while the top-3 was still filling up). It can *also* mean "this item's count wasn't high enough to beat the current lowest-ranked member, so it was never admitted at all." By the time `evt_d` (count `1`) is added, the top-3 is already `evt_a`(5)/`evt_c`(4)/`evt_b`(2) — `evt_d` doesn't beat `evt_b`'s `2`, so it's silently rejected rather than evicting anyone.

```
$ docker exec redis-modern-data-models redis-cli TOPK.LIST trending:events:practice WITHCOUNT
1) "evt_a"
2) (integer) 5
3) "evt_c"
4) (integer) 4
5) "evt_b"
6) (integer) 2
```
`evt_a`, `evt_c`, `evt_b`, with their true counts (5, 4, 2) — `evt_d` isn't present, matching step 2's finding.

```
$ docker exec redis-modern-data-models redis-cli TOPK.QUERY trending:events:practice evt_a evt_d
1) (integer) 1
2) (integer) 0
```
Confirms it directly: `evt_a` is in the top-k, `evt_d` is not.

```
$ docker exec redis-modern-data-models redis-cli TOPK.INCRBY trending:events:practice evt_d 10
1) "evt_b"
$ docker exec redis-modern-data-models redis-cli TOPK.LIST trending:events:practice WITHCOUNT
1) "evt_d"
2) (integer) 11
3) "evt_a"
4) (integer) 5
5) "evt_c"
6) (integer) 4
```
This time `evt_b` gets evicted and `evt_d` takes the top spot with `11`. The difference from step 2 is purely about the *size* of the increment relative to the current top-k's lowest count: adding `evt_d` one point at a time (step 2) never gave it enough count in a single comparison to beat `evt_b`'s `2`, but jumping it by `10` in one `TOPK.INCRBY` call instantly puts it above everyone — the same real-world distinction between "slowly trending up" and "sudden viral spike."

```
$ docker exec redis-modern-data-models redis-cli CMS.INITBYDIM search:queries:practice 2000 7
OK
$ docker exec redis-modern-data-models redis-cli CMS.INCRBY search:queries:practice "indie rock" 4 "jazz brunch" 6 "indie rock" 2
1) (integer) 4
2) (integer) 6
3) (integer) 6
$ docker exec redis-modern-data-models redis-cli CMS.QUERY search:queries:practice "indie rock" "jazz brunch" "polka"
1) (integer) 6
2) (integer) 6
3) (integer) 0
```
Yes — `"indie rock"` ends at `4 + 2 = 6`, matching both the third `CMS.INCRBY` reply and the `CMS.QUERY` result; `"jazz brunch"` is `6` either way; `"polka"`, never incremented, correctly reads back `0`. With only a handful of distinct terms against a `2000`x`7` sketch, there's essentially no hash-collision noise here — the estimates are exact in this example, though at much higher cardinality relative to the sketch's size, `CMS.QUERY` could start overestimating (never underestimating) some terms' true counts.
