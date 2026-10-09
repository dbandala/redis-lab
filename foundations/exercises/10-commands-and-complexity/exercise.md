# Exercise 10 — Commands and Complexity

1. Run the seed script and confirm the list has 5,000 elements:
   ```
   ./seed-biglist.sh
   <!-- TODO: check LLEN biglist:demo -->
   ```
2. Time 1,000 repeated calls of a full-range `LRANGE` against `biglist:demo`, then time 1,000 repeated calls of a bounded 10-element `LRANGE` against the same list. Compare the two totals.
3. Check `OBJECT ENCODING` on `biglist:demo` — has it been promoted past `listpack` at this size?
4. Fill in the table below using each command's official doc page (`redis.io/docs/latest/commands/<name>/`):

   | Command | Time complexity (from docs) |
   |---|---|
   | `GET` | |
   | `SET` | |
   | `HGET` | |
   | `HGETALL` | |
   | `SADD` | |
   | `SMEMBERS` | |
   | `ZADD` | |
   | `ZRANK` | |
   | `LRANGE` | |
   | `KEYS` | |

Check your answers against [solutions/10-commands-and-complexity/solution.md](../../solutions/10-commands-and-complexity/solution.md).
