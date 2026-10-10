# Exercise 02 — Secondary Indexing & Full-Text Search

Keep using the `idx:events` index and the four events from the lesson (`evt100`-`evt400`). Run these against the lab (`docker exec redis-modern-data-models redis-cli ...` or an interactive `redis-cli` session).

1. Add a fifth event, `event:evt500`: `name` = `"Lantern Night Market"`, `venue` = `"Fairgrounds"`, `city` = `"Austin"`, `tags` = `["market", "family-friendly", "outdoor"]`, `capacity` = `10000`, `price` = `15`, `views` = `0`, `soldOut` = `false`. Don't touch the index.
2. Run `FT.SEARCH idx:events "@city:{Austin}"` again. How many results now, and why didn't you need to recreate or rebuild `idx:events` after step 1?
3. Run a full-text search for `Market` against `idx:events`. Which event comes back, and which field matched?
4. Write a numeric range query that finds events with `capacity` strictly greater than `3000` (hint: `(` makes a range bound exclusive). Which events qualify?
5. Write one query that finds events in Austin whose name mentions "Night" (combine a `TAG` filter with a `TEXT` term in a single `FT.SEARCH` call).
6. Run `FT.EXPLAIN` on the query from step 5 and identify which part of the plan is the tag filter and which part is the text match.

Check your answers against [solutions/02-secondary-indexing-and-search/solution.md](../../solutions/02-secondary-indexing-and-search/solution.md).
