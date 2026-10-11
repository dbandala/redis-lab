# Exercise 08 — Authentication & ACLs

Run these against the base lab (`docker exec redis-architecture-and-operations redis-cli ...`).

1. `SET pulse:event:evt5 "Harbor Comedy Hour"` as the `default` user, so there's something to read.
2. Create a **read-only reporting** user named `pulse-reports`, password `r3port-pass`, restricted to keys matching `pulse:event:*`, allowed to run only `GET` and `MGET`, with `resetchannels`. Confirm its shape with `ACL GETUSER pulse-reports`.
3. Connect as `pulse-reports` (`redis-cli -u redis://pulse-reports:r3port-pass@localhost:6379 ...`) and `GET pulse:event:evt5`. Confirm it works.
4. As the same user, try `SET pulse:event:evt5 "overwritten"`. What's the exact error?
5. As the same user, try `GET pulse:session:tok1` — a key outside the granted pattern. What's the exact error, and how does its wording differ from step 4's?
6. As the `default` user, run `ACL CAT` and find the category name that would have let you grant `pulse-reports` broad read access (`GET`, `MGET`, `EXISTS`, `TTL`, etc.) in one clause instead of naming each command. What's that category called?
7. Conceptual: `pulse-reports` was created with `resetchannels` and no `+subscribe`/`+psubscribe` grant. If Pulse's reporting dashboard later needed to subscribe to a live event-updates Pub/Sub channel using this same user, what's the minimal additional ACL change you'd make — and why is `resetchannels` a sensible *default* for a new user even though it means remembering to grant channel access explicitly later?

Check your answers against [solutions/08-security-auth-and-acls/solution.md](../../solutions/08-security-auth-and-acls/solution.md).
