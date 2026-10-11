# Exercise 07 — Client-Side Caching

This exercise needs **two real terminal windows** open against the base lab at the same time — it can't be done by copy-pasting into one script, for the reason explained in the lesson.

**Terminal 1 ("Session A" — the tracking connection):**
```
docker exec -it redis-architecture-and-operations redis-cli -3
```

**Terminal 2 ("Session B" — a plain, separate connection):**
```
docker exec -it redis-architecture-and-operations redis-cli
```

1. In Session A: `SET pulse:event:evt2 "Sunset Jazz Night"` first (so there's something to read), then `HELLO 3`, then `CLIENT TRACKING on`, then `GET pulse:event:evt2`.
2. In Session B: `SET pulse:event:evt2 "changed by session B"`.
3. Back in Session A: without typing anything else yet, do you see an unsolicited message appear? Press Enter once if nothing seems to show up immediately — what shows up, and what are its two parts?
4. In Session B, now `SET pulse:event:evt3 "never read on session A's connection"` — a key Session A's connection never ran a `GET` on. Does Session A receive anything for this one? Why or why not, based on how default-mode tracking decides what to watch?
5. In Session A, run `CLIENT TRACKINGINFO`. What does `flags` show now compared to a fresh connection that never ran `CLIENT TRACKING on`?
6. Conceptual: RESP2 (the protocol every earlier lesson in this course has implicitly used) has no concept of an unsolicited push message outside of Pub/Sub. If a client library wanted to support client-side caching over a RESP2-only connection, what workaround would it have to resort to instead of a clean invalidation push, and why would that be strictly worse?

Check your answers against [solutions/07-client-side-caching/solution.md](../../solutions/07-client-side-caching/solution.md).
