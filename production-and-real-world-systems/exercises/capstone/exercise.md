# Exercise — Capstone: Pulse Goes Live

Bring up this capstone's stack: `docker compose -f compose/observability.yml up -d` (same stack as Lesson 01 — tear down any other Level 5 stack first).

Work from this directory (`exercises/capstone/`) so `pulse_capstone.py` is importable by name.

## Setup

1. Run `python3 seed_pulse.py`. Confirm it reports seeding `pulse:db:event:vip1` with 1 VIP slot remaining. Re-running it at any point resets the scenario to a clean slate — use it freely while testing.

## Implement `pulse_capstone.py`

The file ships with six function stubs, each raising `NotImplementedError`. Implement each one — the docstring on each function specifies its exact required return shape; `race_runner.py` and `verify.sh` depend on matching it precisely.

2. `cache_aside_get_event(pool, event_id)` — Lesson 03's pattern. Check the cache, fall back to the DB hash on a miss, populate the cache with `CACHE_TTL_S`.
3. `write_through_update_price(pool, event_id, new_price)` — Lesson 03's pattern. Update the DB and cache hashes together.
4. `try_claim_vip_slot(pool, event_id, agent_id)` — Lesson 04's pattern, the heart of this capstone. Acquire the lock (spin-retry if it's held), take a fencing token via `INCR`, check and decrement `vip_slots_remaining`, record `last_fencing_token` on the DB hash, and always release the lock safely (`DELEX ... IFEQ`, never a bare `DEL`) in a `finally` block.
5. `rate_limited(pool, agent_id)` — Lesson 05's `FixedWindowLimiter` pattern, using `RATE_LIMIT`/`RATE_WINDOW_S`.
6. `enqueue_notification(pool, claim_result)` and `process_notifications(pool, consumer)` — Lesson 05's reliable-queue pattern.

## Manually exercise what you built

7. Call `cache_aside_get_event` twice for `vip1`; confirm `"MISS"` then `"HIT"`, and confirm `TTL pulse:cache:event:vip1` is set.
8. Call `write_through_update_price`; confirm the cache reflects the new price immediately.
9. Run `python3 race_runner.py lock_race`. Confirm exactly one of the two printed results has `"success": true`, and that `pulse:db:event:vip1`'s `vip_slots_remaining` is `0` afterward (re-run `seed_pulse.py` first if you've already claimed the slot in a manual test above).
10. Run `python3 race_runner.py rate_limit_hammer`. Confirm `accepted` is exactly `3` and `rejected` is greater than `0`.
11. Enqueue a notification for the race's winning result, confirm the pending list is non-empty, then run `process_notifications` and confirm the pending list is empty and a `pulse:notified:<agent_id>` marker key exists for the winner.

## Write the production-readiness memo

12. Fill in `memo.md`'s four sections (`Dataset vs Memory Budget`, `Durability Requirements`, `Transactional Needs`, `Recommendation`), applying Lesson 08's framework to Pulse's ticket-purchase data — the same analysis Lesson 08's own exercise asked for.

## Self-check

13. Run `bash verify.sh` from this directory. It reseeds the scenario itself, so no need to re-seed first. Confirm it reports `0 failed`. Run it a second time to confirm the result isn't flaky.

## Stretch (not scripted — Lesson 07 is discussion-only)

14. Lesson 07 covered Active-Active geo-distribution and the fractured hyperscaler managed-Redis landscape. In a sentence or two, note whether Pulse's current architecture (built across this whole course) would need any changes to run Active-Active across two regions — there's no script to check this against; it's a design question to carry forward.

Compare your work against [solution.md](solution.md) once you're done — not before.
