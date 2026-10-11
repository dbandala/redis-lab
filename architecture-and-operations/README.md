# Level 4 — Architecture & Operations

Hands-on module for Level 4 of the [Redis course](../REDIS_COURSE.md): persistence (RDB vs AOF), replication and manual failover, high availability with Redis Sentinel, horizontal scaling with Redis Cluster (hash slots, resharding, multi-key limits), eviction policies and memory management, client-side caching with RESP3 tracking, and security (authentication, ACLs, TLS, network isolation). Every lesson operates **Pulse**'s Redis infrastructure from Levels 2–3 under conditions that actually require a production topology, culminating in a capstone that fails over a live primary and proves the whole stack survives it.

> **This module is structurally different from Levels 1–3.** Persistence, eviction, client-side caching, and the ACL/TLS security lessons run on the same single-node pattern you already know. Replication, Sentinel, and Cluster genuinely cannot be demonstrated on one node — those lessons bring up their **own** multi-container Docker Compose topology from `compose/`, used for that lesson (or pair of lessons) only, then torn down before moving on. Each lesson says exactly which stack to run.

## Prerequisites

- Everything from [Level 1 — Foundations](../foundations/README.md), [Level 2 — Data Modeling & Core Patterns](../data-modeling/README.md), and [Level 3 — Modern Data Models](../modern-data-models/README.md) — this module assumes the Pulse scenario and core data types are already familiar
- Docker Desktop (or Docker Engine + the Compose v2 plugin) installed and running
- `openssl` (for Lesson 09's self-signed certificate generation — ships standard on macOS/Linux)
- ~3 GB free disk space — the Cluster lesson briefly runs 7 containers at once

## Quick start

Most lessons use the same base stack as earlier levels. Stop any other level's stack first:
```
(cd ../foundations && docker compose down)
(cd ../data-modeling && docker compose down)
(cd ../modern-data-models && docker compose down)
```

Then, for the base-stack lessons (01, 06, 07, 08):
```
cd architecture-and-operations
docker compose up -d
docker exec -it redis-architecture-and-operations redis-cli PING     # expect: PONG
```

For Lessons 02, 03, 04–05, and 09, bring up **that lesson's own stack** instead (and tear down the previous one first — see each lesson for its exact `compose -f ...` command):
```
docker compose down                                   # if the base stack is running
docker compose -f compose/replication.yml up -d       # Lesson 02
docker compose -f compose/sentinel.yml up -d           # Lesson 03, and the capstone
docker compose -f compose/cluster.yml up -d            # Lessons 04-05
docker compose -f compose/tls.yml up -d                # Lesson 09 (run ./scripts/generate-certs.sh first)
```

Open [http://localhost:8001](http://localhost:8001) for RedisInsight against the base stack, or `http://localhost:8004` against the Cluster stack (the only other topology that includes it — see the version note below).

## Lesson index

Work through lessons in order. Attempt each exercise yourself before checking its solution.

| # | Lesson | Lab stack | Exercise | Solution |
|---|--------|-----------|----------|----------|
| 01 | [Persistence: RDB vs AOF](lessons/01-persistence.md) | base | [exercise](exercises/01-persistence/exercise.md) | [solution](solutions/01-persistence/solution.md) |
| 02 | [Replication](lessons/02-replication.md) | `compose/replication.yml` | [exercise](exercises/02-replication/exercise.md) | [solution](solutions/02-replication/solution.md) |
| 03 | [High Availability with Redis Sentinel](lessons/03-sentinel-and-high-availability.md) | `compose/sentinel.yml` | [exercise](exercises/03-sentinel-and-high-availability/exercise.md) | [solution](solutions/03-sentinel-and-high-availability/solution.md) |
| 04 | [Redis Cluster Fundamentals](lessons/04-cluster-fundamentals.md) | `compose/cluster.yml` | [exercise](exercises/04-cluster-fundamentals/exercise.md) | [solution](solutions/04-cluster-fundamentals/solution.md) |
| 05 | [Redis Cluster Operations](lessons/05-cluster-operations.md) | `compose/cluster.yml` | [exercise](exercises/05-cluster-operations/exercise.md) | [solution](solutions/05-cluster-operations/solution.md) |
| 06 | [Eviction Policies & Memory Management](lessons/06-eviction-and-memory-management.md) | base | [exercise](exercises/06-eviction-and-memory-management/exercise.md) | [solution](solutions/06-eviction-and-memory-management/solution.md) |
| 07 | [Client-Side Caching with RESP3 Tracking](lessons/07-client-side-caching.md) | base | [exercise](exercises/07-client-side-caching/exercise.md) | [solution](solutions/07-client-side-caching/solution.md) |
| 08 | [Security I — Authentication & ACLs](lessons/08-security-auth-and-acls.md) | base | [exercise](exercises/08-security-auth-and-acls/exercise.md) | [solution](solutions/08-security-auth-and-acls/solution.md) |
| 09 | [Security II — TLS & Network Isolation](lessons/09-security-tls-and-network-isolation.md) | `compose/tls.yml` | [exercise](exercises/09-security-tls-and-network-isolation/exercise.md) | [solution](solutions/09-security-tls-and-network-isolation/solution.md) |
| — | **Capstone: Pulse Uptime** | `compose/sentinel.yml` | [exercise](exercises/capstone/exercise.md) | [solution](solutions/capstone/solution.md) |

## Teardown

Whichever stack is currently up:
```
docker compose down                                   # base stack
docker compose -f compose/<file>.yml down             # any other topology
docker compose -f compose/<file>.yml down -v           # also delete its data volumes — use between cohorts/restarts
```

## Version and licensing note

Same lab image as Levels 1–3: **Redis 8.10.1** via the official `redis` Docker image — no `redis-stack-server`, no extra modules. Every multi-node topology in this module (`replication.yml`, `sentinel.yml`, `cluster.yml`, `tls.yml`) runs that exact same image, just with different flags/container counts; nothing here requires a different Redis build. RedisInsight (3.8.0) is included only in the base stack and `cluster.yml` — the other topologies are CLI-only, since no lesson transcript in this course ever drives RedisInsight directly.

## Further learning

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" and "RU302: Running Redis at Scale" map closely onto this module's Sentinel and Cluster lessons, respectively; "RU330: Redis Security" covers the ACL/TLS lessons in more depth.

## What's next

Continue to Level 5 in [REDIS_COURSE.md](../REDIS_COURSE.md).
