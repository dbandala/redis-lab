# Level 1 — Foundations

Hands-on module for Level 1 of the [Redis course](../REDIS_COURSE.md): what Redis is, how to run it, the five core data types, key management (TTL and naming), `SCAN` vs `KEYS`, and reading command complexity — plus a bonus lesson on basic security.

## Prerequisites

- Docker Desktop (or Docker Engine + the Compose v2 plugin) installed and running
- ~2 GB free disk space for images + a data volume
- A terminal. You do **not** need `redis-cli` installed on your host — every exercise runs it inside the container via `docker exec`.

## Quick start

```
cd foundations
docker compose up -d
docker compose ps
docker exec -it redis-foundations redis-cli PING     # expect: PONG
```

Then open [http://localhost:8001](http://localhost:8001) for RedisInsight and add a database connection: host `redis`, port `6379`, no password. RedisInsight's own backend takes a few seconds longer than Redis to become ready — if the page doesn't load immediately, wait ~10 seconds and refresh.

## Lesson index

Work through lessons in order. Attempt each exercise yourself before checking its solution.

| # | Lesson | Exercise | Solution |
|---|--------|----------|----------|
| 01 | [What Is Redis?](lessons/01-what-is-redis.md) | [exercise](exercises/01-what-is-redis/exercise.md) | [solution](solutions/01-what-is-redis/solution.md) |
| 02 | [Installing and Running](lessons/02-installing-and-running.md) | [exercise](exercises/02-installing-and-running/exercise.md) | [solution](solutions/02-installing-and-running/solution.md) |
| 03 | [Strings](lessons/03-strings.md) | [exercise](exercises/03-strings/exercise.md) | [solution](solutions/03-strings/solution.md) |
| 04 | [Lists](lessons/04-lists.md) | [exercise](exercises/04-lists/exercise.md) | [solution](solutions/04-lists/solution.md) |
| 05 | [Hashes](lessons/05-hashes.md) | [exercise](exercises/05-hashes/exercise.md) | [solution](solutions/05-hashes/solution.md) |
| 06 | [Sets](lessons/06-sets.md) | [exercise](exercises/06-sets/exercise.md) | [solution](solutions/06-sets/solution.md) |
| 07 | [Sorted Sets](lessons/07-sorted-sets.md) | [exercise](exercises/07-sorted-sets/exercise.md) | [solution](solutions/07-sorted-sets/solution.md) |
| 08 | [TTL and Key Naming](lessons/08-ttl-and-key-naming.md) | [exercise](exercises/08-ttl-and-key-naming/exercise.md) | [solution](solutions/08-ttl-and-key-naming/solution.md) |
| 09 | [SCAN vs KEYS](lessons/09-scan-vs-keys.md) | [exercise](exercises/09-scan-vs-keys/exercise.md) | [solution](solutions/09-scan-vs-keys/solution.md) |
| 10 | [Commands and Complexity](lessons/10-commands-and-complexity.md) | [exercise](exercises/10-commands-and-complexity/exercise.md) | [solution](solutions/10-commands-and-complexity/solution.md) |
| 11 (bonus) | [Security Basics](lessons/11-security-basics-bonus.md) | [exercise](exercises/11-security-basics-bonus/exercise.md) | [solution](solutions/11-security-basics-bonus/solution.md) |
| — | **Capstone: Mini Blog Hot-Data Layer** | [exercise](exercises/capstone/exercise.md) | [solution](solutions/capstone/solution.md) |

## Teardown

```
docker compose down       # stop and remove containers, keep data volumes
docker compose down -v    # also delete the data volumes — use between cohorts/restarts
```

## Version and licensing note

This lab runs **Redis 8.10.1** via the official `redis` Docker image, plus **RedisInsight 3.8.0** as a separate container (see Lesson 02 for why this replaces the older all-in-one `redis/redis-stack` image). Redis 8.0+ ships under a tri-license (RSALv2, SSPLv1, or AGPLv3 — distributor's choice); AGPLv3 is the OSI-approved open-source option. **Valkey**, a BSD-licensed, wire-compatible fork maintained by the Linux Foundation, exists as a direct response to Redis's 2024 license change and is worth knowing about (see Lesson 01) — this course labs against mainline Redis because that's what current official docs, tutorials, and certifications are written against.

## Further learning

[Redis University](https://university.redis.io) is Redis's free, official, self-paced learning platform, including paths toward the Redis Associate certifications. It's a good supplement to this hands-on module — not a replacement for it.

## What's next

Continue to Level 2 in [REDIS_COURSE.md](../REDIS_COURSE.md).
