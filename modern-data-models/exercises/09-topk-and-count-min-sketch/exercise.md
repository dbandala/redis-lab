# Exercise 09 — Top-K & Count-Min Sketch

Run these against the lab.

1. Reserve a Top-K structure `trending:events:practice` tracking the top `3` (width `50`, depth `5`, decay `0.9`).
2. In one `TOPK.ADD` call, add this sequence: `evt_a` five times, `evt_b` twice, `evt_c` four times, `evt_d` once. Look at the 12 reply values — are any of them a non-`nil` eviction? Why or why not, given `evt_d` only appears once?
3. Run `TOPK.LIST ... WITHCOUNT`. Which three events made the cut, and with what counts?
4. Run `TOPK.QUERY` for `evt_a` and `evt_d`. Does the result match step 3?
5. Simulate a push-notification surge: `TOPK.INCRBY trending:events:practice evt_d 10`. What got evicted this time, and why did the outcome differ from step 2's attempt to get `evt_d` in?
6. Separately, initialize a Count-Min Sketch `search:queries:practice` (width `2000`, depth `7`), then in one `CMS.INCRBY` call increment `"indie rock"` by `4`, `"jazz brunch"` by `6`, and `"indie rock"` again by `2`. Run `CMS.QUERY` for both terms plus a term you never incremented, `"polka"`. Do the numbers match what you'd expect from manually adding up the increments?

Check your answers against [solutions/09-topk-and-count-min-sketch/solution.md](../../solutions/09-topk-and-count-min-sketch/solution.md).
