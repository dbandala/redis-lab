# Exercise 05 — Rate Limiters & Job Queues

Work from the project root so `exercises/02-client-libraries-and-connection-pooling` (for `pulse_pool.py`) is importable.

1. Implement `FixedWindowLimiter` as a class with an `allow(key)` method, parameterized by `limit` and `window_s`. Instantiate it with `limit=3`, call `allow("agent:7")` five times in a row, and confirm the results are `[True, True, True, False, False]`.
2. Implement `enqueue_notification(r, agent_id, payload)` (an `LPUSH` onto `pulse:queue:notifications:pending`) and `process_notifications(r, consumer)` (a loop that `LMOVE`s items from `pending` into `processing:<consumer>`, "processes" them, then `LREM`s them from `processing:<consumer>` to acknowledge). Enqueue two notifications and confirm `process_notifications` drains the pending list to `0` and returns both payloads.
3. Simulate a worker crash: enqueue one more notification, `LMOVE` it into a *different* consumer's processing list, but don't call the ack step. Confirm the item is still sitting in that processing list, recoverable — not lost.
4. In one or two sentences, say what you'd need to add to this lesson's hand-rolled queue to make it production-ready the way BullMQ or Celery already is (pick at least one capability from the lesson's comparison table) — and separately, say whether Pulse's VIP-claim notification job (small volume, no scheduling or priority needs) justifies adopting one of those frameworks, or whether the hand-rolled version is enough.
5. In one sentence, say when you'd reach for Streams + consumer groups (Level 3, Lesson 07) instead of this lesson's list-based queue for a new feature.

Compare your work against [solution.md](solution.md) once you're done — not before.
