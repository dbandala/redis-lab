# Exercise 05 — Hashes

1. Create a hash `user:1001` with fields `name` = `"Ada"`, `email` = `"ada@example.com"`, `plan` = `"free"`, all in one command.
2. Read back all fields and values in the hash.
3. Read back just the `name` and `plan` fields in a single command.
4. Add a `login_count` field and increment it by 1 atomically (don't read-then-write from your client).
5. Remove the `plan` field entirely, then confirm it's gone.
6. Check `OBJECT ENCODING` on `user:1001`.
7. Set a 60-second TTL on just the `email` field (not the whole hash), then confirm that field's remaining TTL.
8. Confirm `name` still has no TTL of its own (the hash key itself is still permanent).

Check your answers against [solutions/05-hashes/solution.md](../../solutions/05-hashes/solution.md).
