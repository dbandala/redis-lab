# Lesson 05 — Bitmaps and BITFIELD

## Learning Objectives

By the end of this lesson you can:
- Set, read, count, and find bits with `SETBIT`/`GETBIT`/`BITCOUNT`/`BITPOS`
- Combine bitmaps with `BITOP` (`AND`/`OR`/`XOR`/`NOT`) to answer set-like questions (e.g. "active both days")
- Use `BITFIELD` to pack several small compact counters into one key, with explicit overflow handling

## Concept

A **bitmap** is just a Redis string addressed one bit at a time — there's no new type, only new commands. It's the answer to Lesson 01's "one bit of state per id, millions of ids" row: a daily-active-fan flag for a million users costs ~125KB as a bitmap (1 bit each) versus megabytes as a `SET` of user ids (each with per-member overhead).

```
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-10-08 42 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-10-08 7 1
(integer) 0
$ docker exec redis-data-modeling redis-cli GETBIT bitmap:dau:2026-10-08 42
(integer) 1
$ docker exec redis-data-modeling redis-cli GETBIT bitmap:dau:2026-10-08 99
(integer) 0
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:2026-10-08
(integer) 3
$ docker exec redis-data-modeling redis-cli BITPOS bitmap:dau:2026-10-08 1
(integer) 7
```

The bit offset **is** the user id — user `42` being active on `2026-10-08` means offset `42` is `1`. `SETBIT`'s return value is the bit's *previous* value, not confirmation of the new one. `BITCOUNT` with no range gives the day's total active-user count; `BITPOS key 1` finds the first active user id in the bitmap (here, user `7`, since it was set before user `42` numerically and the bitmap only cares about offset order, not insertion order).

`BITOP` combines bitmaps bit-by-bit — useful for "active on both days" (retention) or "active on either day" (reach):

```
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-10-09 42 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-10-09 55 1
(integer) 0
$ docker exec redis-data-modeling redis-cli BITOP AND bitmap:dau:retained:1008-1009 bitmap:dau:2026-10-08 bitmap:dau:2026-10-09
(integer) 126
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:retained:1008-1009
(integer) 1
$ docker exec redis-data-modeling redis-cli BITPOS bitmap:dau:retained:1008-1009 1
(integer) 42
```

Only user `42` was active on both days, so the `AND` leaves exactly one bit set — this is day-over-day retention computed server-side with a single command, no client-side set intersection needed.

**`BITFIELD`** turns a bitmap into an array of small fixed-width counters packed into one key — handy when you need several bounded counters per user without a key per counter:

```
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:42 SET u8 "#0" 10
1) (integer) 0
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:42 INCRBY u8 "#0" 5
1) (integer) 15
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:42 OVERFLOW SAT INCRBY u8 "#0" 250
1) (integer) 255
```

`u8 "#0"` addresses an 8-bit unsigned field at slot 0 (slot *index*, not bit offset — `#0` means "the 0th 8-bit field," `#1` would be the next 8 bits, and so on). The field maxes out at 255; by default `BITFIELD` would **wrap** past that (overflow back to a small number), but `OVERFLOW SAT` clamps it to the type's max instead — the right choice for a counter that should stop at its ceiling rather than silently wrapping to a tiny, wrong-looking value. `OVERFLOW FAIL` is the third option, returning `nil` for that sub-operation instead of wrapping or clamping, if you'd rather detect the overflow and handle it yourself.

## Official Docs

- [SETBIT](https://redis.io/docs/latest/commands/setbit/)
- [BITCOUNT](https://redis.io/docs/latest/commands/bitcount/)
- [BITPOS](https://redis.io/docs/latest/commands/bitpos/)
- [BITOP](https://redis.io/docs/latest/commands/bitop/)
- [BITFIELD](https://redis.io/docs/latest/commands/bitfield/)

## Exercise

→ [exercises/05-bitmaps-and-bitfields/exercise.md](../exercises/05-bitmaps-and-bitfields/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — bitmaps and `BITFIELD` appear in the "RU101" data-structures-deep-dive material alongside HyperLogLog.
