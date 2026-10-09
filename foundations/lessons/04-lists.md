# Lesson 04 — Lists

## Learning Objectives

By the end of this lesson you can:
- Push, pop, and range over a Redis list
- Move an element between two lists atomically with `LMOVE`
- Explain why `listpack` and `quicklist` encodings exist, and why a full `LRANGE` is O(N)

## Concept

A Redis **list** is an ordered collection of strings, implemented as a linked list of small memory chunks — good for queues, stacks, and capped activity feeds.

Core commands: `LPUSH`/`RPUSH` (push to the left/right end), `LPOP`/`RPOP` (pop from an end), `LRANGE start stop` (read a range — `0 -1` means "everything"), `LLEN`, `LINSERT ... BEFORE|AFTER`, `LTRIM` (keep only a range, discard the rest — the standard way to cap a list's size), and `LMOVE source destination LEFT|RIGHT LEFT|RIGHT`, which atomically pops from one list and pushes onto another (or the same) list — useful for reliable queue patterns where you don't want to lose an item between the pop and the next push.

**Encoding:** small lists use the compact `listpack` encoding (a flat, contiguous memory layout). Once a list grows past `list-max-listpack-size` entries (128 by default), Redis converts it to `quicklist`, a linked list of listpack nodes — more overhead per node, but scales to millions of elements without needing one giant contiguous allocation.

**Complexity to internalize now:** `LPUSH`/`RPUSH`/`LPOP`/`RPOP` are O(1) — they only touch an end of the list. `LRANGE 0 -1` (the whole list) is **O(N)** — it has to walk every element. `LINSERT` is O(N) because it has to find the pivot element first. You'll formalize this table in Lesson 10.

**Try it:**
```
$ docker exec redis-foundations redis-cli RPUSH queue:emails "a@x.com" "b@x.com" "c@x.com"
(integer) 3
$ docker exec redis-foundations redis-cli LRANGE queue:emails 0 -1
1) "a@x.com"
2) "b@x.com"
3) "c@x.com"
```

## Official Docs

- [LPUSH](https://redis.io/docs/latest/commands/lpush/)
- [LRANGE](https://redis.io/docs/latest/commands/lrange/)
- [LMOVE](https://redis.io/docs/latest/commands/lmove/)

## Exercise

→ [exercises/04-lists/exercise.md](../exercises/04-lists/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101" covers lists alongside queue and stack design patterns.
