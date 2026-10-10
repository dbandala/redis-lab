# Capstone Exercise — Pulse Discover

Work through these in order against the lab.

1. **Catalog & hybrid index.** Run `python3 seed-events.py | docker exec -i redis-modern-data-models redis-cli --no-raw`. It loads 6 JSON events (`discover:event:d1`-`d6`, each with a `vibe` vector) into `idx:discover_events`, and 9 support-FAQ documents (`discover:kb:k1`-`k9`, each with an `embedding`) into `idx:discover_kb`. Confirm both index counts: `FT.SEARCH idx:discover_events "*" LIMIT 0 0` and `FT.SEARCH idx:discover_kb "*" LIMIT 0 0`.

2. **Hybrid recommendation query.** Pack the query vector `[0.85, 0.15, 0.75, 0.75]` (high-energy, danceable) into float32 bytes with Python, and run a hybrid query against `idx:discover_events`: `@city:{Austin}=>[KNN 2 @vibe $BLOB AS score]`. Confirm the top result is `discover:event:d1` ("Night Lights Festival").

3. **Catalog aggregation.** Run `FT.AGGREGATE` on `idx:discover_events`, grouping by `@city` with a `COUNT` and an `AVG` of `@price`. Which city has more events in the catalog, and what's its average price?

4. **Support KB hybrid query.** A user asks a refund question. Pack the query vector `[0.88, 0.12, 0.12, 0.2]` and run a hybrid query against `idx:discover_kb`: `@category:{refunds}=>[KNN 1 @embedding $BLOB AS score]`. Confirm the top (and only) result is `discover:kb:k1`.

5. **Activity stream & consumer group.** Create a consumer group `grp:discover:analytics` on a new stream `stream:pulse:discover:activity` (`$ MKSTREAM`). Append 5 activity entries of your choosing (an `event`, `action`, and `user` field each — reusing `d1`-`d6` as event ids is fine). Have `worker-1` read all 5 with `XREADGROUP ... COUNT 5 ... >`.

6. **Partial ack & recovery.** `XACK` 3 of the 5 entries `worker-1` just read. Then have `worker-2` run `XAUTOCLAIM ... 0 0` to sweep up the 2 still-pending entries, and `XACK` those too. Confirm `XPENDING` (summary form) now shows `0` pending.

7. **Webhook dedup.** `BF.RESERVE webhooks:seen:discover` with a 1% error rate and capacity `1000`. `BF.ADD` a webhook ID `whk_launch_01`. Simulate the payment provider retrying the same webhook by calling `BF.ADD` on it again — confirm the return value tells you it's a duplicate.

8. **Resale fraud guard.** `CF.RESERVE resale:listed:discover` with capacity `500`. List two ticket codes for resale, `TCK-7001` and `TCK-7002`, with `CF.ADDNX`. Attempt to list `TCK-7001` again and confirm it's rejected. Then `TCK-7001`'s listing is cancelled (refunded) — remove it with `CF.DEL` and confirm `CF.EXISTS` now reports it absent, while `TCK-7002` is still listed.

9. **Trending now & search analytics.** `TOPK.RESERVE trending:events:discover` for the top `3` (width `50`, depth `5`, decay `0.9`). Feed it this exact view/purchase sequence in one `TOPK.ADD` call: `d1 d1 d1 d3 d5 d5 d5 d5 d2`. Confirm `d5` comes out on top. Separately, `CMS.INITBYDIM search:queries:discover 2000 7` and, in one `CMS.INCRBY` call, increment `"jazz night"` by `5` and `"rock"` by `2`. Confirm both with `CMS.QUERY`.

10. Run `bash verify.sh` and get every check to `PASS`.

Check your answers against [solutions/capstone/solution.md](../../solutions/capstone/solution.md).
