# Lesson 03 — Strings

## Learning Objectives

By the end of this lesson you can:
- Use `SET`'s modern option flags (`NX`, `XX`, `GET`, `EX`/`PX`/`EXAT`/`PXAT`, `KEEPTTL`) instead of legacy dedicated commands
- Use `INCR`/`INCRBY`, `APPEND`, `STRLEN`, `MSET`/`MGET`, `GETDEL`
- Read `OBJECT ENCODING` to see how Redis stores a string internally

## Concept

The **string** is Redis's simplest type: a key mapped to a binary-safe sequence of bytes (up to 512 MB) — text, a number, a serialized blob, whatever.

**Modern `SET` options.** Since Redis 6.0/6.2, `SET` grew option flags that cover what used to require separate commands:

| Legacy command | Modern equivalent |
|---|---|
| `SETNX key val` | `SET key val NX` |
| `SETEX key sec val` | `SET key val EX sec` |
| `PSETEX key ms val` | `SET key val PX ms` |
| `GETSET key val` | `SET key val GET` |

Prefer the `SET ... <flag>` form in new code — it's one command to learn instead of four, and flags compose (e.g. `SET key val NX EX 60` sets only if absent *and* with a 60-second TTL, atomically).

- `NX` — set only if the key does **not** exist
- `XX` — set only if the key **already** exists
- `GET` — return the previous value atomically as part of the `SET`
- `EX seconds` / `PX milliseconds` — set an expiration
- `EXAT unix-seconds` / `PXAT unix-ms` — expire at an absolute timestamp
- `KEEPTTL` — overwrite the value but keep any existing TTL (without this flag, a plain `SET` clears the TTL)

**`OBJECT ENCODING`** shows you the internal representation Redis chose for a value — useful for building intuition about memory efficiency:
- `int` — the string holds a value that fits in a 64-bit integer, stored as an actual integer, not text
- `embstr` — a short (≤ 44 bytes) immutable string, allocated in one memory block together with its object header
- `raw` — a longer string, or one that's been mutated in place (e.g. via `APPEND`), stored separately from its header

**Try it:**
```
$ docker exec redis-foundations redis-cli SET user:1:name "Ada Lovelace"
OK
$ docker exec redis-foundations redis-cli GET user:1:name
"Ada Lovelace"
$ docker exec redis-foundations redis-cli SET counter:visits 0
OK
$ docker exec redis-foundations redis-cli INCR counter:visits
(integer) 1
$ docker exec redis-foundations redis-cli OBJECT ENCODING counter:visits
"int"
```

## Official Docs

- [SET](https://redis.io/docs/latest/commands/set/)
- [GET](https://redis.io/docs/latest/commands/get/)
- [INCR](https://redis.io/docs/latest/commands/incr/)
- [OBJECT ENCODING](https://redis.io/docs/latest/commands/object-encoding/)

## Exercise

→ [exercises/03-strings/exercise.md](../exercises/03-strings/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — the "RU101: Introduction to Redis Data Structures" course covers strings alongside the other core types with interactive quizzes.
