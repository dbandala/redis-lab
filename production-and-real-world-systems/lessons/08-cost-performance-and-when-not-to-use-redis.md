# Lesson 08 — Cost, Performance & When NOT to Use Redis

> **This lesson is non-hands-on by design**, for the same reason Lesson 07 is: there's no local lab for a cost decision. The exercise is a short written memo applying this lesson's framework to Pulse — the same memo the capstone also requires.

## Learning Objectives

By the end of this lesson you can:
- Apply a repeatable decision framework — not a gut feeling — to decide whether a given piece of data belongs in Redis
- Explain the concrete mechanism behind each of the framework's four failure conditions (not just name them)
- Estimate, at a rough order of magnitude, why Redis's $/GB is higher than a disk-backed store's, and when that premium is worth paying anyway

## Concept

Every lesson in this course has been "how to do X well in Redis." This lesson is the necessary counterpart: **how to decide X doesn't belong in Redis at all.** Teams that skip this question tend to discover the answer during an incident — a dataset that outgrew memory, a durability assumption that turned out to be wrong, a transaction that needed guarantees Redis was never designed to give. A framework applied once, deliberately, up front is cheaper than that incident.

### Four conditions, checked in order

**1. Does the dataset fit comfortably in memory, with headroom?** Redis keeps (almost) everything in RAM — that's the entire source of its speed. A dataset that's `80%+` of available memory isn't just "tight," it's one traffic spike or one unlucky `BGSAVE` fork away from an eviction storm (Level 4, Lesson 06) or an OOM kill. Rough math matters here: Redis's per-key overhead (object headers, hash table buckets) means a million small hashes can easily cost several times their raw payload size in actual RSS — "will the data fit" is a real calculation, not an assumption, and it needs to account for replica memory too (Level 4, Lesson 02), not just the primary's.

**2. Does the durability guarantee you actually need exceed what `appendfsync always` gives you?** Level 4, Lesson 01 covered the dial: `always` fsyncs every write before acknowledging it — the strongest durability Redis offers, and it's still "an fsync to local disk," not a cross-datacenter-replicated, point-in-time-recoverable guarantee the way a mature RDBMS or a managed transactional store provides. If the actual requirement is "this write must survive the complete loss of the machine it was written to, with zero chance of loss, verifiable after the fact" — that's a durability bar Redis alone, even configured maximally, isn't built to clear as its primary job.

**3. Does the operation need multi-record ACID guarantees?** `MULTI`/`EXEC` (Level 2) gives you atomicity for a batch of commands, and `WATCH` gives you optimistic-locking isolation for one key — genuinely useful, and enough for a lot of real problems. It is not a multi-table, multi-row, roll-back-on-any-failure transaction the way a relational database's `BEGIN`/`COMMIT` is. "Update this ticket's status AND decrement that revenue ledger AND the two must both succeed or both roll back, across two independent Redis keys that might even live on different Cluster shards" is a correctness requirement Redis's primitives don't natively provide — Level 4's Cluster lesson already flagged this as the multi-key operation limitation, and it's precisely why it matters here.

**4. Are the values themselves oversized for what Redis is built for?** Redis is built for many small-to-medium keys accessed at extremely high rates — not a handful of 500MB blobs. A single large value blocks the event loop for the duration of operations on it (serialization, replication propagation, a fork's copy-on-write overhead during `BGSAVE`) in ways that are invisible at small value sizes and very visible at large ones. Large binary payloads (video, full-resolution images, large file attachments) belong in object storage with Redis holding a reference (a URL, a key), not the blob itself.

If the honest answer to **any** of these four is "yes, this exceeds what Redis gives me" — that piece of data needs a different primary home, with Redis at most caching a view of it (exactly Lesson 03's cache-aside/write-through boundary, and Lesson 06's "ephemeral tier vs. source of truth" classification revisited one more time, now as an explicit checklist instead of an intuition).

### The $/GB premium, and when it's worth paying

In-memory storage costs meaningfully more per GB than disk-backed storage — RAM itself is more expensive than SSD/HDD per gigabyte, full stop, and that gap shows up directly in managed-Redis pricing versus a managed relational or disk-backed NoSQL database at the same data volume. That premium buys you sub-millisecond latency and very high throughput per node — worth paying for hot-path data accessed constantly (session stores, leaderboards, real-time counters, caches in front of a slower store) and hard to justify for data accessed rarely, where a disk-backed store's higher latency never actually gets noticed by anything. The question isn't "is Redis more expensive per GB" (it is, reliably) — it's "is this specific dataset's access pattern hot enough that the latency Redis buys is worth that premium," evaluated per dataset, not as a blanket policy for an entire system.

### Applying the framework to Pulse

| Pulse data | Fits in memory? | Durability need exceeds `always`? | Needs multi-record ACID? | Oversized values? | Verdict |
|---|---|---|---|---|---|
| Session tokens, rate-limit counters | Yes, trivially | No — losing one is a minor inconvenience | No | No | **Redis-native**, no backing store needed |
| Event catalog cache (Lesson 03) | Yes | No — `pulse:db:event:*` is the real backing store | No | No | **Cache only**, source of truth lives elsewhere |
| Confirmed ticket purchase / payment | Possibly | **Yes** — needs durable, auditable, recoverable-after-total-loss guarantees | **Yes** — ticket decrement + payment record must be atomic together | No | **Does not belong in Redis as the primary store** |
| Full event media (posters, seating-chart images) | N/A | N/A | N/A | **Yes** — large binary blobs | **Object storage**, Redis holds a reference only |

This table is exactly the shape this lesson's exercise — and the capstone's required memo — asks you to produce for Pulse's actual data, not a hypothetical one.

## Official Docs

- [Redis memory optimization](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/memory-optimization/)
- [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [Transactions](https://redis.io/docs/latest/develop/interact/transactions/)

## Exercise

→ [exercises/08-cost-performance-and-when-not-to-use-redis/exercise.md](../exercises/08-cost-performance-and-when-not-to-use-redis/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" covers the durability half of this framework in depth; a good next step beyond this course is reading a postmortem from a team that over-relied on Redis as a system of record — several are public and specific about exactly which of this lesson's four conditions they missed.
