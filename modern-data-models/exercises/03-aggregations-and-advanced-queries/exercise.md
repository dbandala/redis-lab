# Exercise 03 — Aggregations & Advanced Queries

Keep using `idx:events` and the five events from Lesson 02 (`evt100`-`evt500`). Run these against the lab.

1. Run an `FT.AGGREGATE` that groups by `@tags` and counts events per tag, sorted by count descending (and alphabetically by tag as a tiebreaker). Which tag has the most events, and does the group count match what you'd expect given one event (`evt200`) carries both `jazz` and `21+`?
2. Run an aggregation that groups by `@city` and computes the **maximum** `capacity` per city with `REDUCE MAX`. Which city's largest venue is bigger?
3. Using `LOAD` + `APPLY`, compute a derived field `price_per_1000_seats` = `price / capacity * 1000` for every event, sorted descending. Which event has the highest price-per-seat-slot, and which has the lowest?
4. Add `"Lantern Night Market"` (score `2`) to the `autocomplete:events` suggestion dictionary (it should already have the other four event names in it from the lesson). Confirm the dictionary's size with `FT.SUGLEN`, then run `FT.SUGGET` with the prefix `La`.
5. Remove `"Downtown Jazz Brunch"` from the dictionary with `FT.SUGDEL` and confirm the new size with `FT.SUGLEN`.

Check your answers against [solutions/03-aggregations-and-advanced-queries/solution.md](../../solutions/03-aggregations-and-advanced-queries/solution.md).
