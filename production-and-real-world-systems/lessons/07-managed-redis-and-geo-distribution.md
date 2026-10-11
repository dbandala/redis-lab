# Lesson 07 — Managed Redis & Geo-Distribution

> **This lesson is non-hands-on by design.** There is no local Docker Compose stack for a managed cloud service — the entire point of this lesson is understanding a landscape you can't `docker exec` into. The exercise is a short decision-matrix writing task, not a `redis-cli` transcript.

## Learning Objectives

By the end of this lesson you can:
- Name Redis Ltd's current commercial product names and what each one is for
- Explain what Active-Active geo-distribution actually does and the mechanism (CRDTs) that makes it possible
- Explain why the three major hyperscalers' "managed Redis" offerings are no longer equivalent to each other, or to Redis itself, as of 2026
- Decide, for a given deployment, whether a hyperscaler's managed option or Redis Ltd's own offering is the better fit

## Concept

Every lesson in this course ran against `redis:8.10.1` in a local container. Production Pulse would almost certainly run against *someone's* managed service instead — self-hosting Redis at scale (the replication/Sentinel/Cluster operational burden from Level 4) is a real, ongoing cost most teams would rather not carry themselves. The landscape for "someone else's managed Redis" changed meaningfully in the last two years, and it's no longer one simple landscape.

### Redis Ltd's own offerings: Redis Cloud and Redis Software

Redis Ltd (the company behind open-source Redis) sells two commercial products, confirmed current as of this course's research:
- **Redis Cloud** — fully managed, Redis-hosted-for-you, the direct equivalent of "I don't want to run any infrastructure at all."
- **Redis Software** — the current name for what was previously branded **Redis Enterprise** (the rename is recent; expect to see "Redis Enterprise" in anything written before ~2025). This is the self-managed or on-prem option: you (or your own cloud account) run it, but you get the Enterprise feature set — clustering, high availability up to 99.999%, and the geo-distribution feature below.

Both are built on the same underlying Enterprise engine, so **Active-Active geo-distribution** (below) is available from either, not just the hosted one.

### Active-Active: multi-region writes without manual conflict resolution

Level 4 covered replication and Sentinel — one primary accepts writes, replicas follow it, and a failover promotes a new primary. That model has an inherent limitation for a global audience: all writes still funnel through **one** primary region at a time, so a user on the other side of the planet pays that round-trip latency on every write, and a regional outage means a failover, not graceful degradation.

**Active-Active** removes the single-primary constraint entirely: multiple regions each accept writes **simultaneously**, with every region's data converging to the same eventual state automatically. This is possible because Active-Active databases are built on **CRDTs** (Conflict-free Replicated Data Types) — data structures mathematically designed so that concurrent updates from different regions can always be merged into one consistent result without needing a human (or a lock, or a quorum vote) to arbitrate conflicts. The model Redis documents this under is **strong eventual consistency**: regions can briefly disagree on a value immediately after a concurrent write, but they are guaranteed to converge to the same final state — no manual conflict resolution step, ever.

For Pulse, this is the feature that would let a venue's box office in one region and a web checkout flow served from another region both update the same event's ticket count with local (same-region) latency, instead of both having to round-trip to one designated primary region. (Deciding whether that's architecturally worth it for Pulse — versus accepting single-region writes with Level 4's Sentinel failover — is exactly the kind of tradeoff Lesson 08's framework is for.)

### New in 2026 — Smart Client Handoffs

Worth knowing about because it already showed up in this course's own client code: **Smart Client Handoffs** is a Redis Cloud/Redis Software feature where the server proactively warns compatible clients *before* a planned maintenance event (a shard migration, a version upgrade, a failover) — the client gets a heads-up, reconnects to the right endpoint, and temporarily relaxes its timeouts while the transition completes, instead of experiencing a hard disconnect mid-request. Lesson 02's `redis-py` `Redis.__init__` signature already carries `maint_notifications_config` and `oss_cluster_maint_notifications_handler` parameters for exactly this — support for it is already built into the client this course uses, even though this lab's plain OSS container never triggers it (there's no managed-service maintenance event to receive).

### The hyperscaler landscape has fractured — know this before recommending a vendor

Level 1 introduced Redis's 2024 license change (to the dual RSALv2/SSPLv1 + AGPLv3 model) and the **Valkey** fork that followed. By 2026 that fork has produced a very real, very material consequence worth knowing before recommending a cloud vendor:

| Provider | What's actually running | Current Redis 8 features (JSON/Search/Vector/probabilistic)? |
|---|---|---|
| **AWS ElastiCache** | Three engines offered: **Valkey** (now the default for new clusters, up to 9.1) and **Redis OSS** — frozen at **version 7.1** (GA'd November 2023; AWS never shipped 7.2, 7.4, or 8.0 on this engine) | No, not on the Redis OSS engine — only via Valkey's separate `valkey-search` module, a different codebase |
| **AWS MemoryDB** | Also Valkey-based now (Valkey 9.1 as of mid-2026) | Same caveat as above |
| **Google Cloud Memorystore** | Defaults to **Valkey** for new instances since 2025 | Same caveat |
| **Azure** | **Azure Cache for Redis** (the old product) is being **retired** — Basic/Standard/Premium tiers by September 30, 2028, the Enterprise tier by March 30, 2027. Its replacement, **Azure Managed Redis**, is built *in partnership with Redis Ltd*, directly on **Redis Software** | Yes — because it's genuine current Redis, not a fork |
| **Redis Cloud / Redis Software** (Redis Ltd's own) | Genuine Redis, current version | Yes |

The practical upshot: "managed Redis" is no longer a commodity choice between interchangeable hosting providers. If a workload needs Redis 8's native JSON/Search/vector/probabilistic structures (everything Level 3 taught), AWS's and GCP's default managed paths **do not have them** — you'd need Redis Ltd's own Redis Cloud, or Azure's new Redis-Ltd-partnered offering, or you'd need to adopt Valkey (a different, compatible-but-diverging project) and its separate module ecosystem instead. This is exactly the kind of fast-moving, vendor-specific detail that goes stale within a year or two — verify current engine/version support directly against each provider's docs before a real procurement decision, rather than trusting any single course (or blog post) as a permanent source of truth.

## Official Docs

- [Redis Cloud](https://redis.io/cloud/)
- [Redis Software](https://redis.io/software/)
- [Active-Active geo-distribution](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [How CRDTs power Active-Active replication](https://redis.io/blog/how-crdts-power-active-active-database-replication/)
- [Smart client handoffs](https://redis.io/docs/latest/develop/clients/sch/)

## Exercise

→ [exercises/07-managed-redis-and-geo-distribution/exercise.md](../exercises/07-managed-redis-and-geo-distribution/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU330: Redis Security" and Redis Ltd's own solution-architecture guides go deeper on Active-Active design patterns than any single lesson can; each hyperscaler's own release notes are the only reliable source for their current engine/version support, since that landscape is actively shifting.
