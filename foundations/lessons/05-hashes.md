# Lesson 05 — Hashes

## Learning Objectives

By the end of this lesson you can:
- Model an object as a Redis hash and read/write individual fields
- Use `HINCRBY` for per-field counters and `HDEL` to remove a field
- Use per-field TTLs (`HEXPIRE`/`HTTL`) — a Redis 7.4+ feature still current in Redis 8

## Concept

A **hash** maps field names to values, all under one key — the natural fit for "an object with named attributes" (a user profile, a product record) without needing a separate key per field.

Core commands: `HSET key field value [field value ...]`, `HGET`/`HMGET` (one or several fields), `HGETALL` (every field+value), `HDEL`, `HINCRBY` (atomic per-field increment, handy for counters that live alongside other object data), `HRANDFIELD` (a random field, useful for sampling), `HEXISTS`.

**Per-field TTL** is a genuinely new capability (introduced in Redis 7.4, present in 8.x): `HEXPIRE key seconds FIELDS numfields field [field ...]` sets an expiration on individual *fields* within a hash, independent of the hash's own key-level TTL. `HTTL` reads it back. This is useful when different attributes of the same object should expire on different schedules — e.g. a `user:*` hash where `email` is permanent but a `password_reset_token` field should vanish after 15 minutes, without needing a second key.

**Encoding:** small hashes use `listpack` (compact, contiguous); once a hash exceeds `hash-max-listpack-entries` (128 by default) or a field/value exceeds `hash-max-listpack-value` (64 bytes by default), Redis converts it to `hashtable`.

**Try it:**
```
$ docker exec redis-foundations redis-cli HSET user:1001 name "Ada" email "ada@example.com" plan "free"
(integer) 3
$ docker exec redis-foundations redis-cli HGETALL user:1001
1) "name"
2) "Ada"
3) "email"
4) "ada@example.com"
5) "plan"
6) "free"
```

## Official Docs

- [HSET](https://redis.io/docs/latest/commands/hset/)
- [HGETALL](https://redis.io/docs/latest/commands/hgetall/)
- [HEXPIRE](https://redis.io/docs/latest/commands/hexpire/)

## Exercise

→ [exercises/05-hashes/exercise.md](../exercises/05-hashes/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101" covers hashes as the standard way to model objects, with a comparison against storing one key per field.
