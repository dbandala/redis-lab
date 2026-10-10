# Exercise 01 — JSON Documents

Run these against the lab (`docker exec redis-modern-data-models redis-cli ...` or an interactive `redis-cli` session).

1. Create a JSON document `event:evt200` with one `JSON.SET` call: `name` = `"Sunset Jazz Night"`, `venue` = `"Blue Note Hall"`, `city` = `"Denver"`, `tags` = `["jazz", "indoor"]`, `capacity` = `800`, `price` = `45`, `views` = `0`, `soldOut` = `false`.
2. Read back just the `venue` field with a single `JSON.GET` + JSONPath call.
3. Increment `views` by 1 three separate times using `JSON.NUMINCRBY`. What's the final value, and what did you call to read it back without re-incrementing?
4. Append `"21+"` to the `tags` array with `JSON.ARRAPPEND`, then confirm with `JSON.GET`.
5. Use `JSON.MERGE` to set `soldOut` to `true` — without touching any other field — then confirm `views` is still untouched.
6. Run `TYPE` and `OBJECT ENCODING` on `event:evt200`. Why doesn't `TYPE` report `string`, even though `JSON.GET` prints what looks like a quoted string to `redis-cli`?

Check your answers against [solutions/01-json-documents/solution.md](../../solutions/01-json-documents/solution.md).
