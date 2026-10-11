# Exercise 03 — Caching Patterns: Cache-Aside & Write-Through

Work from the project root so `exercises/02-client-libraries-and-connection-pooling` (for `pulse_pool.py`) is importable.

1. Seed a "source of truth" hash `pulse:db:event:evt1` with fields `name="Night Lights Festival"` and `price="89.00"`.
2. Implement `cache_aside_get_event(event_id)`: check `pulse:cache:event:<id>` first; on a miss, read `pulse:db:event:<id>`, populate the cache with a 30-second TTL, and return the data along with whether it was a `"HIT"` or `"MISS"`.
3. Call it twice for `evt1`. Confirm the first call reports `"MISS"` and the second reports `"HIT"`. Confirm `TTL pulse:cache:event:evt1` is `30` (or close to it) after the first call.
4. Implement `write_through_update_price(event_id, new_price)`: update both `pulse:db:event:<id>` and `pulse:cache:event:<id>` together.
5. Call it to change `evt1`'s price to `"99.00"`. Confirm `pulse:cache:event:evt1`'s `price` field reflects `"99.00"` **immediately** (no waiting, no re-fetch) — and confirm its TTL is unchanged from step 3, not reset.
6. Now simulate the cache-aside staleness gap: delete the cache key, re-populate it via `cache_aside_get_event`, then update *only* the database hash directly (bypass `write_through_update_price` — call `HSET` on `pulse:db:event:evt1` directly). Confirm a subsequent `cache_aside_get_event` call still returns the **old** cached price — the cache won't catch up until its TTL expires or something explicitly repopulates it.
7. In one sentence, say which of the two patterns you'd use for Pulse's event *listings page* (shows name/venue/date, read constantly, rarely changes) vs. its *checkout price display* (must reflect the latest price the instant it changes).

Compare your work against [solution.md](solution.md) once you're done — not before.
