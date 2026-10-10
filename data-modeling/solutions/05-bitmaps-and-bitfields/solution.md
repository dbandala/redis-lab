# Solution 05 — Bitmaps and BITFIELD

```
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-01 3 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-01 19 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-01 88 1
(integer) 0
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:2026-11-01
(integer) 3
```

```
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-02 19 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-02 42 1
(integer) 0
$ docker exec redis-data-modeling redis-cli SETBIT bitmap:dau:2026-11-02 88 1
(integer) 0
```

```
$ docker exec redis-data-modeling redis-cli BITOP AND bitmap:dau:retained:1101-1102 bitmap:dau:2026-11-01 bitmap:dau:2026-11-02
(integer) 12
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:retained:1101-1102
(integer) 2
$ docker exec redis-data-modeling redis-cli BITPOS bitmap:dau:retained:1101-1102 1
(integer) 19
```
Two users were active both days — `19` and `88` — so `BITCOUNT` reports `2`, not `1`; `BITPOS` only finds the *first* set bit (`19`), not all of them, so checking a specific user still needs `GETBIT` on that offset once you know it's a candidate.

```
$ docker exec redis-data-modeling redis-cli BITOP OR bitmap:dau:reach:1101-1102 bitmap:dau:2026-11-01 bitmap:dau:2026-11-02
(integer) 12
$ docker exec redis-data-modeling redis-cli BITCOUNT bitmap:dau:reach:1101-1102
(integer) 4
```
4 users: `3`, `19`, `42`, `88` — the union of `{3, 19, 88}` and `{19, 42, 88}` has 4 distinct members, matching `BITCOUNT`.

```
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:19 SET u8 "#0" 200
1) (integer) 0
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:19 OVERFLOW SAT INCRBY u8 "#0" 100
1) (integer) 255
```
`200 + 100 = 300`, which exceeds the `u8` max of `255`. With `OVERFLOW SAT`, the result clamps at the ceiling (`255`) instead of becoming `300` — an unsigned 8-bit field can never represent `300` at all.

```
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:19 SET u8 "#0" 200
1) (integer) 255
$ docker exec redis-data-modeling redis-cli BITFIELD stats:bitfield:user:19 INCRBY u8 "#0" 100
1) (integer) 44
```
With default (wrap) overflow behavior, `300` wraps around modulo `256` (the field's range), landing at `300 - 256 = 44` — a silently wrong-looking small number instead of a clamped ceiling. This is exactly why `OVERFLOW SAT` matters for a counter: without it, a counter that's "full" can wrap back down to near-zero and look like it just reset, rather than staying pinned at its maximum.
