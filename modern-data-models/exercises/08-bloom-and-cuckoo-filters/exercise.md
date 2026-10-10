# Exercise 08 — Bloom & Cuckoo Filters

Run these against the lab.

1. Create a Bloom filter `webhooks:seen:practice` with a 2% false-positive rate and capacity for 500 items, then add three webhook IDs (`whk_a1`, `whk_b2`, `whk_c3`) in a single `BF.MADD` call.
2. Check `BF.EXISTS` for `whk_a1` and for a webhook ID you never added, `whk_never_sent`. What do you get for each?
3. Run one `BF.MEXISTS` call checking all three added IDs plus `whk_never_sent` together. Confirm it matches what you'd expect from step 2.
4. Call `BF.ADD` again on `whk_a1` (already added). What does the return value tell you, and how would a webhook handler use that return value to decide whether to re-process a request?
5. Create a Cuckoo filter `redeemed:evt300:practice` with capacity 200. Use `CF.ADDNX` to add ticket codes `TCK-1001` and `TCK-1002`, then try `CF.ADDNX` on `TCK-1001` again. What's different about `CF.ADDNX`'s behavior here compared to what `BF.ADD` did in step 4?
6. `TCK-1001` gets refunded. Remove it from `redeemed:evt300:practice` with `CF.DEL`, then confirm with `CF.EXISTS` that it's gone while `TCK-1002` still shows as redeemed. Why couldn't you do this step with a Bloom filter?

Check your answers against [solutions/08-bloom-and-cuckoo-filters/solution.md](../../solutions/08-bloom-and-cuckoo-filters/solution.md).
