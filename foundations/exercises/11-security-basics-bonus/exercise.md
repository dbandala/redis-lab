# Exercise 11 (Bonus) — Security Basics

1. Check who you are and what the default user's ACL rule looks like:
   ```
   <!-- TODO: ACL WHOAMI -->
   <!-- TODO: ACL LIST -->
   ```
2. Create a new user `student`, enabled, with password `student-pass`, restricted to keys matching `cache:*`, and allowed to run only `GET`, `SET`, and `PING`.
3. Connect as `student` (via `redis-cli --user student --pass student-pass ...`) and confirm:
   - `PING` succeeds
   - `SET cache:test "ok"` succeeds
   - `SET user:9999 "blocked"` fails with `NOPERM`
   - `GET user:1001` fails with `NOPERM`
4. Still as `student`, try `ACL WHOAMI`. Does it succeed? Why or why not?
5. Delete the `student` user and confirm `ACL LIST` is back to just `default`.

Check your answers against [solutions/11-security-basics-bonus/solution.md](../../solutions/11-security-basics-bonus/solution.md).
