# Capstone Exercise — Mini Blog Hot-Data Layer

See [README.md](README.md) for the scenario. Use these exact key names so `verify.sh` can check your work.

1. Create three users as hashes: `user:1`, `user:2`, `user:3`, each with fields `name`, `email`, `plan`.
2. Create a session string `session:demo` holding a user id, with a 5-minute TTL, set in a single command.
3. Create tag sets for three articles: `article:1:tags`, `article:2:tags`, `article:3:tags` — make sure at least one tag appears in more than one article. Compute the tags shared between `article:1:tags` and `article:2:tags`.
4. For `article:1`, record a view both as a plain string counter `article:1:views` (increment it) **and** as a score in a sorted set `leaderboard:articles:views` (increment `article:1`'s score there too) — the same event updating two structures.
5. Maintain a capped recent-activity feed: push `"article:1"` onto the left of `feed:global` each time it's viewed, then trim `feed:global` down to at most its 20 most recent entries.
6. Enumerate all three tag-set keys using `SCAN` with a `MATCH` pattern — **not** `KEYS`.
7. Check `TTL session:demo`, then `PERSIST` it, and confirm `TTL` now reports no expiration.
8. Run `OBJECT ENCODING` on at least two of the structures you created above, and be ready to explain each encoding.
9. Run `bash verify.sh` and get every check to `PASS`.

Check your work against [solutions/capstone/solution.md](../../solutions/capstone/solution.md).
