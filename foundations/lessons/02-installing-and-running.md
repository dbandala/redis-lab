# Lesson 02 — Installing and Running Redis

## Learning Objectives

By the end of this lesson you can:
- Start the module's lab environment with Docker Compose
- Run commands against Redis with `redis-cli`
- Open RedisInsight and browse keys visually

## Concept

You don't need to install Redis on your machine at all — this module runs it in Docker, matching how most teams run Redis locally and in CI. The lab environment (`foundations/docker-compose.yml`) starts two containers:

- **`redis`** — the official `redis:8.10.1` image, exposed on `localhost:6379`, the port every Redis client (including `redis-cli`) talks to.
- **`redisinsight`** — the official `redis/redisinsight:3.8.0` image, a web-based GUI for browsing keys, running commands, and visualizing data structures, exposed on `localhost:8001`.

> **Why two containers instead of the older `redis/redis-stack` all-in-one image?** `redis/redis-stack` bundles Redis together with RedisInsight in a single container, which used to be the simplest path — but as of this writing its published tags are still pinned to Redis 7.4, while the capabilities it used to add on top of "plain" Redis (JSON, search, time series, probabilistic types, vector sets) were folded into Redis core in 8.0. Running the official `redis` image plus a standalone `redisinsight` container gets you the current Redis version *and* the same GUI, at the cost of one extra line in `docker-compose.yml`.

**Try it — start the lab:**
```
cd foundations
docker compose up -d
docker compose ps
```

**Talk to Redis with `redis-cli`**, running *inside* the container (no local Redis install needed):
```
docker exec -it redis-foundations redis-cli PING
```
Expected output: `PONG`.

You can also drop into an interactive session instead of prefixing every command:
```
docker exec -it redis-foundations redis-cli
127.0.0.1:6379> PING
PONG
127.0.0.1:6379> exit
```

**Open RedisInsight:** visit [http://localhost:8001](http://localhost:8001) in a browser. On first launch, add a database connection with host `redis` (the Docker Compose service name — RedisInsight reaches it over the Compose network), port `6379`, no password. You should see an empty database — that's expected, you haven't written any keys yet.

## Official Docs

- [Install Redis](https://redis.io/docs/latest/operate/oss_and_stack/install/)
- [redis-cli reference](https://redis.io/docs/latest/develop/tools/cli/)
- [RedisInsight](https://redis.io/insight/)

## Exercise

→ [exercises/02-installing-and-running/exercise.md](../exercises/02-installing-and-running/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) has a short "Introduction to Redis Data Structures" course covering the same setup steps with videos, if you'd like a second walkthrough.
