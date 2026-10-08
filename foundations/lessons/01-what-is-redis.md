# Lesson 01 — What Is Redis?

## Learning Objectives

By the end of this lesson you can:
- Explain what "in-memory data store" means and why it makes Redis fast
- Explain how Redis's single-threaded command execution model gives you atomicity for free
- State the current Redis licensing model (2026) and why it matters when you pick a Redis distribution
- Name Valkey and explain why it exists

## Concept

**Redis** (**RE**mote **DI**ctionary **S**erver) is an in-memory data structure store. Unlike a traditional database that reads from and writes to disk on every operation, Redis keeps the entire working dataset in RAM, which is why single-key operations complete in microseconds rather than milliseconds. It optionally persists that data to disk (see Level 4 of the course for RDB/AOF) so it can survive a restart, but disk is a backup mechanism, not the read/write path.

**Why it's fast — the single-threaded event loop:** the Redis server processes commands one at a time on a single main thread, using an event loop (multiplexed I/O) to juggle thousands of client connections without needing a thread per connection. Because only one command runs at any instant, every individual command is inherently atomic — no locks, no race conditions between two clients incrementing the same counter. (Redis does use background threads for a few things like lazy-freeing large keys and I/O, but command *execution* stays single-threaded.) You'll feel the benefit of this directly in Lesson 08 when you use commands like `EXPIRE ... GT` that would otherwise need a client-side lock.

**Licensing, as of 2026:** Redis versions up to 7.2 were BSD-3-Clause (fully open source). Starting with 7.4, the project ("Redis Community Edition") moved to a source-available dual license (RSALv2 or SSPLv1) — no longer OSI-approved open source. Since **Redis 8.0**, called "Redis Open Source," you can choose from **three** licenses: RSALv2, SSPLv1, or **AGPLv3** — and AGPLv3 is OSI-approved, so Redis is open source again under that option. This module's lab runs **Redis 8.10.1**.

**Aside — Valkey:** in March 2024, several of Redis's former core maintainers, along with AWS, Google Cloud, Oracle, and others, forked the last BSD-licensed release (7.2.4) into **Valkey**, governed by the Linux Foundation and kept permanently under BSD-3-Clause. AWS ElastiCache/MemoryDB now default to Valkey compatibility. You'll see Valkey mentioned in job postings and cloud provider docs — it's wire-compatible with Redis (same protocol, same commands), so everything you learn in this course transfers directly. This course labs against mainline Redis because that's what current official docs, tutorials, and certifications are written against.

**Try it:** you don't need the lab running yet for this lesson — but if you already have Docker, you can peek ahead:
```
docker run --rm redis:8.10.1 redis-server --version
```

## Official Docs

- [Redis Open Source — Get started](https://redis.io/docs/latest/develop/get-started/data-store/)
- [Redis licensing (official)](https://redis.io/legal/licenses/)

## Exercise

→ [exercises/01-what-is-redis/exercise.md](../exercises/01-what-is-redis/exercise.md)

## Further Reading

Want a deeper, structured treatment of Redis fundamentals with videos and quizzes? [Redis University](https://university.redis.io) is Redis's free official learning platform — a good supplement to this hands-on module, not a replacement for it.
