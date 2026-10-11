# Capstone — Pulse Goes Live

## Scenario

Pulse's VIP-upgrade feature has exactly one remaining slot for tonight's headline show. Two support agents, working on behalf of two different customers, both try to claim it in the same second. This capstone wires together every piece of Level 5 — and, through it, the whole course — into one connected flow: a pooled Python client (Lesson 02) backing a cache-aside read and a write-through price update (Lesson 03), a distributed lock with a fencing token serializing the contested claim (Lesson 04), a rate limiter throttling repeated claim attempts and a reliable queue delivering the confirmation notification (Lesson 05) — all running on `compose/observability.yml` (Lesson 01), so the whole exercise is visible on the Grafana dashboard while it happens. The capstone closes with the same production-readiness memo Lesson 08 asked for, now applied specifically to the data this exercise just touched.

Lesson 07 (managed Redis, Active-Active) is a **stretch/discussion item only** — not scripted. There's no local lab for a managed cloud service, and more specifically, nothing about this capstone's single-node scenario requires geo-distribution to be correct; that's a design question worth thinking through, not a check `verify.sh` can run.

## Rubric

Your solution is complete when:
- All six functions in `pulse_capstone.py` are implemented, matching their documented return shapes
- `bash exercises/capstone/verify.sh` reports `0 failed`, run twice in a row to rule out timing flakiness in the lock-race and rate-limiter checks
- `memo.md`'s four required sections are filled in with real analysis (`verify.sh` only checks that the headings exist — the content is on you)
- You can explain why the fencing token is checked by reading it back from `pulse:db:event:vip1` (the *resource*), not just by trusting the lock — and what failure mode that protects against that the lock's safe release (`DELEX ... IFEQ`) alone does not
- You can explain, for the rate-limiter check, why `accepted` must be exactly `3` rather than merely "some number less than the hammer count" — what would an off-by-one bug there actually let through in production

Compare your work against [solution.md](solution.md) once you're done — not before.
