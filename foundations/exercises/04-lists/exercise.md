# Exercise 04 — Lists

1. Push `"a@x.com"`, `"b@x.com"`, `"c@x.com"` onto the right end of `queue:emails` in a single command, then read the whole list back.
2. Pop the leftmost element off `queue:emails`.
3. Push `"priority@x.com"` onto the **left** end of `queue:emails`, then read the whole list back — where does the priority item land?
4. Atomically move the leftmost element of `queue:emails` onto the right end of a new list `queue:emails:processed`. Confirm the item now appears in `queue:emails:processed` and no longer in `queue:emails`.
5. Check `OBJECT ENCODING` on `queue:emails` and its current length (`LLEN`).
6. Insert `"inserted@x.com"` immediately before `"b@x.com"` in `queue:emails`, and confirm the new ordering.
7. Trim `queue:emails` down to just its first two elements, and confirm the rest were discarded.

Check your answers against [solutions/04-lists/solution.md](../../solutions/04-lists/solution.md).
