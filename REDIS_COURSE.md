# A Modern Redis Curriculum

A learning path from zero to production-ready, organized in 5 levels. Redis today is much more than a cache — the path reflects that (JSON, search, vector, streams, AI use cases included).

## Level 1 — Foundations

- What Redis is: in-memory data store, single-threaded event loop, why it's fast
- Installing/running: Docker, `redis-cli`, RedisInsight (GUI)
- Core data types: strings, lists, hashes, sets, sorted sets
- Key management: TTL/expiration, key naming conventions, `SCAN` vs `KEYS`
- Basic commands and O(N) complexity awareness per command

## Level 2 — Data Modeling & Core Patterns

- Choosing the right structure for a problem (counters, leaderboards, session store, rate limiting)
- Sorted sets for leaderboards/priority queues
- HyperLogLog (approximate cardinality), Bitmaps (flags/analytics)
- Geospatial commands
- Transactions: `MULTI`/`EXEC`/`WATCH` (optimistic locking)
- Pub/Sub messaging basics
- Lua scripting (`EVAL`) and why it matters for atomicity

## Level 3 — Modern Data Models (Redis Stack)

- **RedisJSON** — native JSON document storage
- **RediSearch** — secondary indexing, full-text search, aggregations
- **Vector search** — embeddings storage + similarity search (kNN/HNSW) for RAG/AI apps — arguably the most "modern" reason people learn Redis in 2026
- **Redis Streams** — event logs, consumer groups, comparison to Kafka for lightweight event-driven systems
- **Probabilistic data structures** — Bloom/Cuckoo filters, Top-K, Count-Min Sketch

## Level 4 — Architecture & Operations

- Persistence: RDB snapshots vs AOF, tuning durability vs performance
- Replication (primary/replica), failover
- High availability: **Redis Sentinel**
- Horizontal scaling: **Redis Cluster** (hash slots, resharding, multi-key op limitations)
- Eviction policies and memory management (`maxmemory-policy`)
- Client-side caching (RESP3 tracking)
- Security: ACLs, TLS, auth, network isolation

## Level 5 — Production & Real-World Systems

- Observability: `INFO`, latency monitoring, slow log, RedisInsight, Prometheus/Grafana exporters
- Client libraries and connection pooling (patterns per language, e.g. `redis-py`, `ioredis`, `Lettuce`/`Jedis`)
- Common architectures: cache-aside, write-through, distributed locks (Redlock — and its criticisms), rate limiters, job queues (vs BullMQ/Celery)
- Redis in microservices/event-driven architectures
- Managed offerings: Redis Enterprise/Redis Cloud, Active-Active geo-replication
- Cost/perf tradeoffs: when NOT to use Redis

## Suggested Capstone Projects

1. Real-time leaderboard + rate limiter API
2. Semantic search / RAG backend using vector search + JSON
3. Event-driven order pipeline using Streams + consumer groups
4. Multi-node Cluster deployed with Sentinel failover, load-tested
