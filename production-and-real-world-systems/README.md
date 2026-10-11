# Level 5 — Production & Real-World Systems

Hands-on module for Level 5 of the [Redis course](../REDIS_COURSE.md): observability (`INFO`, `SLOWLOG`, `LATENCY`, and a real Prometheus + Grafana pipeline), client libraries and connection pooling, caching patterns (cache-aside, write-through), distributed locks and Redlock, rate limiters and job queues, Redis in microservices/event-driven architectures, managed Redis offerings and geo-distribution, and a cost/performance framework for deciding when Redis *isn't* the right tool. This is the final level of the course: every lesson wires back into **Pulse**, the live-event ticketing platform built across Levels 1–4, culminating in a capstone that makes Pulse's VIP-claim feature production-ready — observable, pooled, cache-backed, race-safe, and rate-limited — all at once.

> **This module adds the course's first pip dependency.** Levels 1–4 were Docker + stdlib-only. From Lesson 02 onward, this module uses `redis-py` directly in Python — connection pooling and retry/backoff aren't meaningfully teachable against bare `redis-cli`.

## Prerequisites

- Everything from [Level 1 — Foundations](../foundations/README.md) through [Level 4 — Architecture & Operations](../architecture-and-operations/README.md) — this module assumes the Pulse scenario, core data types, and Level 4's persistence/replication/security concepts are already familiar
- Docker Desktop (or Docker Engine + the Compose v2 plugin) installed and running
- Python 3 and `pip install "redis==8.1.0"` — a virtualenv is recommended:
  ```
  python3 -m venv .venv && source .venv/bin/activate
  pip install "redis==8.1.0"
  ```
- `curl` (for querying Prometheus/the exporter directly — ships standard on macOS/Linux)
- ~2.5 GB free disk space — Lesson 01's stack runs 5 containers (Redis, RedisInsight, the exporter, Prometheus, and Grafana) at once

## Quick start

This module uses **two** stacks, never both at once — stop whichever is running before switching:

**Base stack** (Lessons 02–06, 08 — no new infrastructure beyond plain Redis):
```
cd production-and-real-world-systems
docker compose up -d
docker exec -it redis-production-and-real-world-systems redis-cli PING     # expect: PONG
```

**Observability stack** (Lesson 01 and the capstone):
```
docker compose down                                      # if the base stack is running
docker compose -f compose/observability.yml up -d
docker exec -it redis-observability redis-cli PING       # expect: PONG
```

With the observability stack up: RedisInsight at [http://localhost:8001](http://localhost:8001), Prometheus at [http://localhost:9090](http://localhost:9090), and Grafana at [http://localhost:3000](http://localhost:3000) (no login required — anonymous viewer access is enabled for this lab; the "Pulse Redis — Level 5 Observability" dashboard is pre-provisioned, nothing to configure).

Lessons 07 and 08 are non-hands-on (decision-matrix exercises) — no stack needed for either.

## Lesson index

Work through lessons in order. Attempt each exercise yourself before checking its solution.

| # | Lesson | Lab stack | Exercise | Solution |
|---|--------|-----------|----------|----------|
| 01 | [Observability & Monitoring](lessons/01-observability-and-monitoring.md) | `compose/observability.yml` | [exercise](exercises/01-observability-and-monitoring/exercise.md) | [solution](exercises/01-observability-and-monitoring/solution.md) |
| 02 | [Client Libraries & Connection Pooling](lessons/02-client-libraries-and-connection-pooling.md) | base | [exercise](exercises/02-client-libraries-and-connection-pooling/exercise.md) | [solution](exercises/02-client-libraries-and-connection-pooling/solution.md) |
| 03 | [Caching Patterns: Cache-Aside & Write-Through](lessons/03-cache-aside-and-write-through.md) | base | [exercise](exercises/03-cache-aside-and-write-through/exercise.md) | [solution](exercises/03-cache-aside-and-write-through/solution.md) |
| 04 | [Distributed Locks & Redlock](lessons/04-distributed-locks-and-redlock.md) | base | [exercise](exercises/04-distributed-locks-and-redlock/exercise.md) | [solution](exercises/04-distributed-locks-and-redlock/solution.md) |
| 05 | [Rate Limiters & Job Queues](lessons/05-rate-limiters-and-job-queues.md) | base | [exercise](exercises/05-rate-limiters-and-job-queues/exercise.md) | [solution](exercises/05-rate-limiters-and-job-queues/solution.md) |
| 06 | [Redis in Microservices & Event-Driven Architectures](lessons/06-microservices-and-event-driven-architecture.md) | base | [exercise](exercises/06-microservices-and-event-driven-architecture/exercise.md) | [solution](exercises/06-microservices-and-event-driven-architecture/solution.md) |
| 07 | [Managed Redis & Geo-Distribution](lessons/07-managed-redis-and-geo-distribution.md) | none (non-hands-on) | [exercise](exercises/07-managed-redis-and-geo-distribution/exercise.md) | [solution](exercises/07-managed-redis-and-geo-distribution/solution.md) |
| 08 | [Cost, Performance & When NOT to Use Redis](lessons/08-cost-performance-and-when-not-to-use-redis.md) | none (non-hands-on) | [exercise](exercises/08-cost-performance-and-when-not-to-use-redis/exercise.md) | [solution](exercises/08-cost-performance-and-when-not-to-use-redis/solution.md) |
| — | **Capstone: Pulse Goes Live** | `compose/observability.yml` | [exercise](exercises/capstone/exercise.md) | [solution](exercises/capstone/solution.md) |

## Teardown

```
docker compose down                                       # base stack
docker compose -f compose/observability.yml down           # observability stack
docker compose -f compose/observability.yml down -v        # also delete its data volumes — use between cohorts/restarts
```

## Version and licensing note

Same lab image as Levels 1–4: **Redis 8.10.1** via the official `redis` Docker image, plus **RedisInsight 3.8.0**. The observability stack adds `oliver006/redis_exporter:v1.93.0`, `prom/prometheus:v3.15.0`, and `grafana/grafana:13.2.3` — none of these touch the Redis image itself, they only read its `INFO` output from outside. See [Level 1, Lesson 01](../foundations/lessons/01-what-is-redis.md) for the full discussion of Redis's tri-license and the Valkey fork; Lesson 07 in this module revisits that fork's real 2026 consequence for managed-Redis vendor selection.

## Further learning

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" and "RU330: Redis Security" both extend topics this module touches; this module's lessons link each client library's and each cloud provider's own current documentation directly, since that landscape moves faster than any single course can track.

## What's next

This is the last level. Revisit [REDIS_COURSE.md](../REDIS_COURSE.md)'s **Suggested Capstone Projects** for a portfolio-ready next project that recombines everything across all five levels — Pulse Goes Live, this module's own capstone, is itself one worked example of exactly that.
