# Exercise 09 — SCAN vs KEYS

1. Run the seed script to populate 50 demo keys, then check the total key count in the database:
   ```
   ./seed-keys.sh
   <!-- TODO: check DBSIZE -->
   ```
2. Use `KEYS` to list every `demo:*` key in one call. This is safe here because the dataset is tiny — explain in one sentence why the same call would be risky against a production database with millions of keys.
3. Iterate the same `demo:*` keys using `SCAN` instead: start with cursor `0` and a `COUNT` of `10`, then keep calling `SCAN` with whatever cursor comes back, until you get cursor `0`. Note how many round trips it took.
4. Run `HSCAN` against `user:1001` (from Lesson 05) and `SSCAN` against `article:42:tags` (from Lesson 06) — both with cursor `0`.

Check your answers against [solutions/09-scan-vs-keys/solution.md](../../solutions/09-scan-vs-keys/solution.md).
