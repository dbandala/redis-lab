# Exercise 03 — Strings

Run these against the lab (`docker exec redis-foundations redis-cli ...` or an interactive `redis-cli` session).

1. Set `user:1:name` to `"Ada Lovelace"`, then read it back.
2. Update `user:1:name` to `"Ada L."`, but only if the key already exists (use the right `SET` flag — don't use a separate `EXISTS` check).
3. Try to create `user:2:name` = `"Grace Hopper"` only if it does **not** already exist. Then try to overwrite it the same way with a different value, and confirm the second attempt has no effect.
4. Create `counter:visits` at `0`, increment it once, then increment it again by `10`. Check its encoding with `OBJECT ENCODING` — what do you see, and why?
5. Set `session:abc123` to `"token-data"` with a 60-second TTL in the same command. Check its `TTL`. Update its value to `"updated-token"` without resetting the TTL. Confirm the TTL is (approximately) unchanged.
6. Atomically read and delete `session:abc123` in one command. Confirm the key no longer exists.
7. Check `OBJECT ENCODING` on `user:1:name` — what encoding do you get, and how does it differ from the encoding of `counter:visits`?
8. Use `APPEND` to add `" (Countess of Lovelace)"` to `user:1:name`, then re-check its length with `STRLEN` and its value with `GET`.
9. Set three keys `a`, `b`, `c` to `1`, `2`, `3` in a single command, then read all three back in a single command.

Check your answers against [solutions/03-strings/solution.md](../../solutions/03-strings/solution.md).
