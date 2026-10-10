# Level 3 — Modern Data Models (Redis Stack)

Hands-on module for Level 3 of the [Redis course](../REDIS_COURSE.md): JSON documents, secondary indexing and full-text search, aggregations, vector search (both native Vector Sets and RediSearch vector fields), building a RAG retrieval pipeline, Redis Streams, consumer groups, and probabilistic data structures (Bloom/Cuckoo filters, Top-K, Count-Min Sketch). Every lesson builds one piece of **Pulse Discover**, a search-and-recommendation layer for the Pulse ticketing platform from Level 2, culminating in a capstone that wires every piece together.

> **"Redis Stack" is not a separate product anymore.** Through 2024, everything in this module shipped as a separately-distributed add-on called Redis Stack. Since **Redis 8.0** (May 2025), JSON, the Query Engine (RediSearch), the probabilistic structures, and a new native Vector Sets type all ship *inside* Redis Open Source itself — this module runs on the exact same `redis:8.10.1` image as Level 1 and Level 2, with no extra image or install step. Lesson 01 covers this in more detail.

## Prerequisites

- Everything from [Level 1 — Foundations](../foundations/README.md) and [Level 2 — Data Modeling & Core Patterns](../data-modeling/README.md) — this module assumes the five core data types, key-naming/TTL conventions, and the Pulse scenario are already familiar
- Docker Desktop (or Docker Engine + the Compose v2 plugin) installed and running
- Python 3 (any recent version — the standard library only, no packages to install) for a few small helper scripts that pack vector-search query bytes and seed demo data
- ~2 GB free disk space for images + a data volume

## Quick start

This module reuses the same host ports (`6379`, `8001`) as Levels 1 and 2. If either stack is still running, stop it first:

```
(cd ../foundations && docker compose down)
(cd ../data-modeling && docker compose down)
```

Then:

```
cd modern-data-models
docker compose up -d
docker compose ps
docker exec -it redis-modern-data-models redis-cli PING     # expect: PONG
```

Open [http://localhost:8001](http://localhost:8001) for RedisInsight and add a database connection: host `redis`, port `6379`, no password. As in Levels 1 and 2, RedisInsight's backend takes a few seconds longer than Redis to become ready — wait ~10 seconds and refresh if the page doesn't load immediately.

## Lesson index

Work through lessons in order. Attempt each exercise yourself before checking its solution.

| # | Lesson | Exercise | Solution |
|---|--------|----------|----------|
| 01 | [JSON Documents (RedisJSON)](lessons/01-json-documents.md) | [exercise](exercises/01-json-documents/exercise.md) | [solution](solutions/01-json-documents/solution.md) |
| 02 | [Secondary Indexing & Full-Text Search](lessons/02-secondary-indexing-and-search.md) | [exercise](exercises/02-secondary-indexing-and-search/exercise.md) | [solution](solutions/02-secondary-indexing-and-search/solution.md) |
| 03 | [Aggregations & Advanced Queries](lessons/03-aggregations-and-advanced-queries.md) | [exercise](exercises/03-aggregations-and-advanced-queries/exercise.md) | [solution](solutions/03-aggregations-and-advanced-queries/solution.md) |
| 04 | [Vector Search Fundamentals](lessons/04-vector-search-fundamentals.md) | [exercise](exercises/04-vector-search-fundamentals/exercise.md) | [solution](solutions/04-vector-search-fundamentals/solution.md) |
| 05 | [Building a RAG Retrieval Pipeline](lessons/05-building-a-rag-pipeline.md) | [exercise](exercises/05-building-a-rag-pipeline/exercise.md) | [solution](solutions/05-building-a-rag-pipeline/solution.md) |
| 06 | [Redis Streams Fundamentals](lessons/06-streams-fundamentals.md) | [exercise](exercises/06-streams-fundamentals/exercise.md) | [solution](solutions/06-streams-fundamentals/solution.md) |
| 07 | [Consumer Groups & Reliable Processing](lessons/07-consumer-groups.md) | [exercise](exercises/07-consumer-groups/exercise.md) | [solution](solutions/07-consumer-groups/solution.md) |
| 08 | [Bloom & Cuckoo Filters](lessons/08-bloom-and-cuckoo-filters.md) | [exercise](exercises/08-bloom-and-cuckoo-filters/exercise.md) | [solution](solutions/08-bloom-and-cuckoo-filters/solution.md) |
| 09 | [Top-K & Count-Min Sketch](lessons/09-topk-and-count-min-sketch.md) | [exercise](exercises/09-topk-and-count-min-sketch/exercise.md) | [solution](solutions/09-topk-and-count-min-sketch/solution.md) |
| — | **Capstone: Pulse Discover** | [exercise](exercises/capstone/exercise.md) | [solution](solutions/capstone/solution.md) |

## Teardown

```
docker compose down       # stop and remove containers, keep data volumes
docker compose down -v    # also delete the data volumes — use between cohorts/restarts
```

## Version and licensing note

Same lab stack as Levels 1 and 2: **Redis 8.10.1** via the official `redis` Docker image, plus **RedisInsight 3.8.0** — no `redis-stack-server` image, no extra modules to install. `MODULE LIST` on this container does show `ReJSON`, `search`, `bf`, `timeseries`, and `vectorset` loaded, but they're compiled into the standard image and auto-loaded; nothing in this module's `docker-compose.yml` adds them. See [Level 1, Lesson 01](../foundations/lessons/01-what-is-redis.md) for the full discussion of Redis's tri-license (RSALv2/SSPLv1/AGPLv3) and the Valkey fork — it isn't repeated here.

## Further learning

[Redis University](https://university.redis.io) — Redis's free, official, self-paced learning platform. Several lessons in this module point to specific RU courses that go deeper on that lesson's topic.

## What's next

Continue to Level 4 in [REDIS_COURSE.md](../REDIS_COURSE.md).
