# Level 2 — Data Modeling & Core Patterns

Hands-on module for Level 2 of the [Redis course](../REDIS_COURSE.md): choosing the right structure for a problem, sorted-set patterns (leaderboards, priority queues), rate limiting, HyperLogLog, bitmaps, geospatial search, transactions (`MULTI`/`EXEC`/`WATCH`), Pub/Sub, and Lua scripting / Redis Functions. Every lesson builds one piece of the hot-data layer for **Pulse**, a fictional live-event ticketing platform, culminating in a capstone that wires all the pieces together on ticket-launch night.

## Prerequisites

- Everything from [Level 1 — Foundations](../foundations/README.md) — this module builds directly on Level 1's sorted-set basics and key-naming/TTL conventions, so working through Level 1 first (or already knowing the five core data types) is assumed
- Docker Desktop (or Docker Engine + the Compose v2 plugin) installed and running
- ~2 GB free disk space for images + a data volume

## Quick start

This module reuses the same host ports (`6379`, `8001`) as Level 1. If the `foundations` stack is still running, stop it first:

```
(cd ../foundations && docker compose down)
```

Then:

```
cd data-modeling
docker compose up -d
docker compose ps
docker exec -it redis-data-modeling redis-cli PING     # expect: PONG
```

Open [http://localhost:8001](http://localhost:8001) for RedisInsight and add a database connection: host `redis`, port `6379`, no password. As in Level 1, RedisInsight's backend takes a few seconds longer than Redis to become ready — wait ~10 seconds and refresh if the page doesn't load immediately.

## Lesson index

Work through lessons in order. Attempt each exercise yourself before checking its solution.

| # | Lesson | Exercise | Solution |
|---|--------|----------|----------|
| 01 | [Choosing the Right Structure](lessons/01-choosing-the-right-structure.md) | [exercise](exercises/01-choosing-the-right-structure/exercise.md) | [solution](solutions/01-choosing-the-right-structure/solution.md) |
| 02 | [Leaderboards and Priority Queues](lessons/02-leaderboards-and-priority-queues.md) | [exercise](exercises/02-leaderboards-and-priority-queues/exercise.md) | [solution](solutions/02-leaderboards-and-priority-queues/solution.md) |
| 03 | [Counters and Rate Limiting](lessons/03-counters-and-rate-limiting.md) | [exercise](exercises/03-counters-and-rate-limiting/exercise.md) | [solution](solutions/03-counters-and-rate-limiting/solution.md) |
| 04 | [HyperLogLog](lessons/04-hyperloglog.md) | [exercise](exercises/04-hyperloglog/exercise.md) | [solution](solutions/04-hyperloglog/solution.md) |
| 05 | [Bitmaps and BITFIELD](lessons/05-bitmaps-and-bitfields.md) | [exercise](exercises/05-bitmaps-and-bitfields/exercise.md) | [solution](solutions/05-bitmaps-and-bitfields/solution.md) |
| 06 | [Geospatial Indexes](lessons/06-geospatial.md) | [exercise](exercises/06-geospatial/exercise.md) | [solution](solutions/06-geospatial/solution.md) |
| 07 | [Transactions: MULTI/EXEC/WATCH](lessons/07-transactions-and-watch.md) | [exercise](exercises/07-transactions-and-watch/exercise.md) | [solution](solutions/07-transactions-and-watch/solution.md) |
| 08 | [Pub/Sub Messaging](lessons/08-pubsub.md) | [exercise](exercises/08-pubsub/exercise.md) | [solution](solutions/08-pubsub/solution.md) |
| 09 | [Lua Scripting and Redis Functions](lessons/09-scripting-and-functions.md) | [exercise](exercises/09-scripting-and-functions/exercise.md) | [solution](solutions/09-scripting-and-functions/solution.md) |
| — | **Capstone: Pulse Live Events — Ticket Launch Night** | [exercise](exercises/capstone/exercise.md) | [solution](solutions/capstone/solution.md) |

## Teardown

```
docker compose down       # stop and remove containers, keep data volumes
docker compose down -v    # also delete the data volumes — use between cohorts/restarts
```

## Version and licensing note

Same lab stack as Level 1: **Redis 8.10.1** via the official `redis` Docker image, plus **RedisInsight 3.8.0**. See [Level 1, Lesson 01](../foundations/lessons/01-what-is-redis.md) for the full discussion of Redis's tri-license (RSALv2/SSPLv1/AGPLv3) and the Valkey fork — it isn't repeated here.

## Further learning

[Redis University](https://university.redis.io) — Redis's free, official, self-paced learning platform. Several lessons in this module point to specific RU courses that go deeper on that lesson's topic.

## What's next

Continue to Level 3 in [REDIS_COURSE.md](../REDIS_COURSE.md).
