# Exercise 04 — Vector Search Fundamentals

Continue from the lesson: `vibes:events` currently has 4 members (`evt400` was removed in the lesson), and `idx:events_vec` indexes `evt100`-`evt500` on their `$.vibe` field.

1. Re-add `evt400` to `vibes:events` with its original vibe `[0.1, 0.9, 0.2, 0.3]`, then add a new member `evt600` with vibe `[0.15, 0.95, 0.25, 0.25]` ("chill, acoustic, mellow"). Confirm `VCARD vibes:events` is now `6`.
2. Run `VSIM` with query vector `[0.15, 0.9, 0.25, 0.3]` (also chill/acoustic) and `COUNT 2`. Which two members come back, and in what order?
3. Create a full JSON event document `event:evt600` — `name` = `"Acoustic Singer-Songwriter Night"`, `venue` = `"The Parlor"`, `city` = `"Austin"`, `tags` = `["acoustic", "indoor"]`, `capacity` = `200`, `price` = `25`, plus `vibe` = `[0.15, 0.95, 0.25, 0.25]` — and confirm it's automatically picked up by `idx:events_vec` with `FT.SEARCH idx:events_vec "@name:Acoustic"`.
4. Pack the same query vector from step 2 into float32 bytes with Python (see the lesson's one-liner) and run the equivalent `FT.SEARCH ... KNN 2 @vibe $BLOB` query against `idx:events_vec`. Does the result order match step 2?
5. Remove `evt600` from `vibes:events` with `VREM`, confirm `VCARD` drops back to `5`, then run the same `FT.SEARCH idx:events_vec "@name:Acoustic"` from step 3 again. Does `event:evt600` still show up — and what does that tell you about how independent Vector Sets and a RediSearch vector index are, even when built from the same underlying data?

Check your answers against [solutions/04-vector-search-fundamentals/solution.md](../../solutions/04-vector-search-fundamentals/solution.md).
