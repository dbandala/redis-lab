# Redis Lab

A free, hands-on Redis course — zero to production-ready, in five self-contained levels. Every exercise runs against a real `redis:8.10.1` container via Docker Compose; every level builds one piece of **Pulse**, a fictional live-event ticketing platform, so the data model and the war stories carry forward instead of resetting with every lesson.

Redis today is far more than a cache. This course reflects that: JSON documents, full-text and vector search, probabilistic data structures, Streams, and RAG patterns sit alongside the classic data types, replication, and Cluster.

See [REDIS_COURSE.md](REDIS_COURSE.md) for the full curriculum outline.

## Why this course

- **Hands-on first.** Every lesson pairs with a `docker compose up` lab, a `redis-cli` (or Python) exercise, and a worked solution — no slides, no videos.
- **One running scenario.** Pulse, a live-event ticketing platform, grows across all 46 lessons: a leaderboard in Level 2 becomes a search index in Level 3, a replicated primary in Level 4, an observable production service in Level 5.
- **Current, not historical.** Labs run on Redis 8.10.1 — JSON, search, and vector types ship *inside* Redis Open Source now (no separate "Redis Stack" image). The tri-license (RSALv2/SSPLv1/AGPLv3) and the Valkey fork are covered directly, not glossed over.
- **Self-contained.** Everything needed to run a lesson — compose files, seed scripts, certs — lives next to it. No shared infra to provision up front.

## Prerequisites

- **Docker Desktop** (or Docker Engine + the Compose v2 plugin), running
- A terminal — `redis-cli` is never required on the host; every exercise runs it inside the container via `docker exec`
- **Python 3** (standard library only until Level 5) for a handful of helper/seed scripts in Levels 3–5
- `openssl` and `curl` for a couple of Level 4/5 lessons (ship standard on macOS/Linux)
- ~3 GB free disk space for images and data volumes at peak (the Cluster lesson briefly runs 7 containers)

No Redis installation, no cloud account, and no paid services are required anywhere in this course.

## Quick start

```bash
git clone git@github.com:dbandala/redis-lab.git
cd redis-lab/foundations
docker compose up -d
docker exec -it redis-foundations redis-cli PING     # expect: PONG
```

Open [http://localhost:8001](http://localhost:8001) for RedisInsight and connect to host `redis`, port `6379`, no password. Then open [foundations/lessons/01-what-is-redis.md](foundations/lessons/01-what-is-redis.md) and start reading.

Each level reuses the same host ports (`6379`, `8001`), so stop one level's stack (`docker compose down`) before starting the next's — every module README spells out the exact command.

## Course structure

| Level | Module | Topics | Lessons |
|---|---|---|---|
| 1 | [Foundations](foundations/README.md) | Core data types, key management, `SCAN` vs `KEYS`, command complexity, security basics | 11 |
| 2 | [Data Modeling & Core Patterns](data-modeling/README.md) | Sorted sets, HyperLogLog, bitmaps, geospatial, transactions, Pub/Sub, Lua scripting | 9 |
| 3 | [Modern Data Models (Redis Stack)](modern-data-models/README.md) | JSON, search & aggregations, vector search & RAG, Streams, probabilistic structures | 9 |
| 4 | [Architecture & Operations](architecture-and-operations/README.md) | Persistence, replication, Sentinel, Cluster, eviction, client-side caching, ACLs/TLS | 9 |
| 5 | [Production & Real-World Systems](production-and-real-world-systems/README.md) | Observability, client pooling, caching patterns, Redlock, rate limiters, managed Redis, cost/perf | 8 |

Work through the levels in order — each one assumes the previous level's concepts and extends the same Pulse scenario. Every module ships its own capstone; the full curriculum's suggested end-to-end capstone projects are listed at the bottom of [REDIS_COURSE.md](REDIS_COURSE.md).

## Repository layout

Each level is a self-contained module with the same shape:

```
<level>/
├── README.md              # module overview, prerequisites, quick start, lesson index
├── docker-compose.yml     # the lab's base Redis (+ RedisInsight) stack
├── compose/               # additional topologies for lessons that need one (replication, cluster, TLS, …)
├── lessons/               # one Markdown lesson per topic — read these first
└── exercises/
    └── <NN-topic>/
        ├── exercise.md    # the hands-on task — attempt this yourself
        └── solution.md    # a worked solution — check only after attempting
```

Lesson numbering is per-module (`01`, `02`, …) and maps 1:1 to the table in each module's `README.md`. Every module also includes a `capstone/` exercise that integrates the whole level.

## Tech stack

- **Redis 8.10.1** (official `redis` Docker image) — every level runs the same image; later levels just add topology (replicas, Sentinel, Cluster nodes) or sidecars, never a different Redis build
- **RedisInsight 3.8.0** — GUI, run as its own container per module
- **Docker Compose v2** — one base stack per module, plus named topology files (`compose/*.yml`) for lessons that need multiple nodes
- **Python 3 + `redis-py`** — introduced in Level 5 for connection pooling, retry/backoff, and client patterns that aren't meaningfully teachable against bare `redis-cli`
- **Prometheus + Grafana + `redis_exporter`** — a real observability pipeline in Level 5, pre-provisioned with a dashboard

Redis 8's tri-license (RSALv2, SSPLv1, or AGPLv3 — distributor's choice) and the **Valkey** fork (BSD-licensed, wire-compatible, Linux Foundation-maintained) are covered in [Level 1, Lesson 01](foundations/lessons/01-what-is-redis.md). This course labs against mainline Redis because that's what current official docs and certifications are written against.

## Further learning

[Redis University](https://university.redis.io) is Redis's free, official, self-paced learning platform, with paths toward the Redis Associate certifications. Several lessons in this course point to specific Redis University courses that go deeper on that lesson's topic — this course is a hands-on complement to it, not a replacement.

## Contributing

This is a personal learning lab. Issues and pull requests (typos, broken commands, clearer explanations) are welcome — open one against [dbandala/redis-lab](https://github.com/dbandala/redis-lab).

## License

No license file is currently included — all rights reserved by default. If you'd like to reuse this material, please open an issue first.
