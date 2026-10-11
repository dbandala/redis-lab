# Solution 08 — Cost, Performance & When NOT to Use Redis

**Step 1 — the framework applied to four Pulse categories:**

**(a) Per-session shopping cart during active browsing:** Fits in memory trivially (small, bounded per user). Durability need doesn't exceed `always` — losing an in-progress, not-yet-checked-out cart is a UX annoyance, not data loss with real consequences. No multi-record ACID need. No oversized values. **Verdict: Redis-native**, no backing store required.

**(b) Confirmed, paid ticket purchase record:** Durability need **exceeds** `always` — this must survive total node loss with a verifiable, auditable record, which is a different guarantee class than "fsynced to this machine's disk." It also needs multi-record ACID — the ticket-availability decrement and the payment/ledger record must succeed or fail together. Either condition alone is enough to settle it. **Verdict: does not belong in Redis as the primary store.**

**(c) Venue's full-resolution seating-chart image:** Oversized value — a large binary blob is exactly what Redis's small-many-keys design is not built for; serializing and replicating a multi-megabyte value on every write is real, avoidable overhead. **Verdict: object storage**, Redis holds a reference (URL/key) at most.

**(d) Live view counter on an event page:** Fits in memory trivially. Durability doesn't exceed `always` — losing a live counter's exact value is unnoticeable, it just recomputes. No multi-record ACID need. No oversized values. **Verdict: Redis-native.**

**Step 2 — what replaces Redis for (b), and Redis's remaining role:**

The ticket purchase record belongs in Pulse's relational database (this course's `pulse:db:event:*` hashes stand in for it, but a real deployment needs an actual durable, transactional datastore — e.g. Postgres) with Redis playing a **cache-aside/write-through** role on top of it (Lesson 03) for read-heavy access to that same data, and the distributed lock from Lesson 04 serializing the contested decrement itself — Redis accelerates and coordinates around the purchase, but the database is the durable record it falls back to.

**Step 3 — why Redis costs more per GB, and why it's worth it for rate limiters:**

Redis keeps data in RAM, and RAM costs meaningfully more per gigabyte than the SSD/HDD a disk-backed store uses — that gap is structural, not a pricing choice any vendor can fully engineer away. For Pulse's rate-limit counters specifically, the premium is clearly worth it: these keys are read and written on **every single request** on the hot path, so the sub-millisecond latency Redis provides directly determines how much request-handling overhead the rate limiter adds — a disk-backed store's latency, even just a few milliseconds extra per check, would be a real, user-visible tax multiplied across every request Pulse serves.

**Step 4 — the memo (same deliverable the capstone requires):**

```markdown
## Dataset vs Memory Budget
Ticket-purchase records for Pulse's current catalog size fit comfortably in memory today,
but this is the wrong frame for this dataset regardless — the decision isn't "does it fit,"
it's that durability and transactional needs (below) already rule out Redis as the primary
store before memory budget is even the deciding factor.

## Durability Requirements
A confirmed, paid ticket purchase must survive the complete loss of any single node, be
recoverable after the fact, and be auditable — a guarantee class beyond what `appendfsync
always` provides (durable against this machine's disk, not against this machine's total loss
with a verifiable audit trail).

## Transactional Needs
Confirming a purchase requires the ticket-inventory decrement and the payment/ledger record
to succeed or fail together, atomically, as one unit — exactly the multi-record ACID guarantee
Redis's `MULTI`/`EXEC`/`WATCH` primitives don't provide across independent keys (and
specifically don't provide at all once those keys live on different Cluster shards).

## Recommendation
Keep the relational database as the durable system of record for ticket purchases, with Redis
layered on top via cache-aside (fast reads of recent/popular events) and a distributed lock
(Lesson 04) serializing the contested decrement itself. Do not attempt to make Redis alone the
primary store for this data — doing so would mean quietly dropping a durability and
transactional guarantee Pulse's ticket-sale and payment data genuinely needs.
```
