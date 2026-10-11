# Solution 07 — Managed Redis & Geo-Distribution

**1. Multi-region concurrent writes:**

The feature is **Active-Active geo-distribution**. It's safe because Active-Active databases are built on **CRDTs** (Conflict-free Replicated Data Types) — data structures specifically designed so that two concurrent, conflicting-looking updates from different regions have a well-defined, deterministic merge result built into the data type itself, rather than needing a human or an application-level conflict-resolution step. Both regions' writes succeed locally and immediately; the regions then converge to the same final state automatically (Redis calls this "strong eventual consistency") — nobody has to decide "whose write wins," because the CRDT's merge rule already decided that.

**2. AWS managed Redis is no longer a safe assumption:**

As of 2026, AWS ElastiCache's default engine for new clusters is **Valkey**, not Redis, and its Redis OSS engine option is frozen at version **7.1** — AWS never shipped 7.2, 7.4, or 8.0 on it, so none of Level 3's JSON/Search/vector/probabilistic features are available there. The two concrete options to get genuine current Redis while staying on AWS infrastructure are: (a) **Redis Cloud**, available directly through the AWS Marketplace, hosted by Redis Ltd rather than AWS itself; or (b) self-managed **Redis Software** running on EC2/EKS instances the team controls, trading the "fully managed" convenience for direct control over the Redis version.

**3. Azure team's migration path:**

Azure Cache for Redis is being **retired** — the Enterprise tier by March 30, 2027, and the Basic/Standard/Premium tiers by September 30, 2028. Microsoft's replacement is **Azure Managed Redis**, built in direct partnership with Redis Ltd on top of Redis Software — meaningfully, this is the one major hyperscaler path that stays on genuine current Redis rather than pivoting to Valkey, which is worth flagging specifically to a team deciding whether to migrate now or wait.

**4. Smart Client Handoffs and why it matters more for payments:**

Smart Client Handoffs lets a compatible client reconnect to the correct new endpoint *before* a planned maintenance event finishes, instead of experiencing a hard mid-request disconnect — it matters far more for a payment-processing request than a cache-aside read because a payment request that's silently dropped mid-flight risks an ambiguous outcome (did the charge go through or not?) that a human then has to reconcile, whereas a dropped cache-aside read just means the application falls back to the source of truth and tries again, with no ambiguity about what state anything ended up in.

**5. Recommendation for Pulse's current deployment:**

Active-Active is not worth adopting yet for Pulse's single-region (US) deployment — the actual problem it solves (local-latency writes from multiple simultaneously-active regions, and tolerating a whole region going dark without failover) doesn't exist until Pulse genuinely has multi-region write traffic. Level 4's Sentinel-based single-primary failover already covers the real, present requirement (surviving the loss of one node without a human paging in), at a fraction of the operational complexity Active-Active would add. Revisit this the moment Pulse actually launches in a second region with real write traffic there — not before, per the same "deploy complexity you don't yet need" trap Lesson 08's framework exists to catch.
