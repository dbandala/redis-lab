# Exercise 06 — Geospatial Indexes

Run these against the lab (`docker exec redis-data-modeling redis-cli ...` or an interactive `redis-cli` session).

1. Create `geo:venues:sf` and add 3 venues of your choosing with distinct coordinates (pick any real or made-up longitude/latitude values, as long as two are close together and one is far away).
2. Get the distance in kilometers between your two closest venues using `GEODIST`.
3. Run a `GEOSEARCH` from one of the close venues using `FROMMEMBER` and a `BYRADIUS` of `3 km`, with `WITHDIST`. Confirm the far-away venue is excluded.
4. Run the same search using `BYBOX 6 6 km` instead of `BYRADIUS`. Do you get the same result set? Why might a box and a circle of similar size differ?
5. Store the radius search from task 3 into `geo:venues:sf:nearby` with `GEOSEARCHSTORE`, then read it back with plain `ZRANGE ... WITHSCORES`. Are the scores distances? If not, what are they?
6. Try `TYPE` on `geo:venues:sf`. What does it report, and what does that tell you about how `GEOADD` is implemented?

Check your answers against [solutions/06-geospatial/solution.md](../../solutions/06-geospatial/solution.md).
