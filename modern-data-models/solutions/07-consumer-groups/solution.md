# Solution 07 — Consumer Groups & Reliable Processing

```
$ docker exec redis-modern-data-models redis-cli XGROUP CREATE stream:pulse:orders:practice grp:practice $ MKSTREAM
OK
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders:practice * event evt400 user u21 qty 1
"1791591038643-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders:practice * event evt400 user u5 qty 2
"1791591038707-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders:practice * event evt600 user u88 qty 5
"1791591038778-0"
$ docker exec redis-modern-data-models redis-cli XADD stream:pulse:orders:practice * event evt600 user u3 qty 1
"1791591038845-0"
```

```
$ docker exec redis-modern-data-models redis-cli XREADGROUP GROUP grp:practice consumer-a COUNT 3 STREAMS stream:pulse:orders:practice >
1) 1) "stream:pulse:orders:practice"
   2) 1) 1) "1791591038643-0" 2) 1) "event" 2) "evt400" ...
      2) 1) "1791591038707-0" 2) 1) "event" 2) "evt400" ...
      3) 1) "1791591038778-0" 2) 1) "event" 2) "evt600" ...
```

```
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:orders:practice grp:practice
1) (integer) 3
2) "1791591038643-0"
3) "1791591038778-0"
4) 1) 1) "consumer-a"
      2) "3"
```
Three entries pending, all assigned to `consumer-a` — exactly the three it just read and hasn't acknowledged yet.

```
$ docker exec redis-modern-data-models redis-cli XACK stream:pulse:orders:practice grp:practice 1791591038643-0
(integer) 1
```
(Re-running `XPENDING` afterward would show `2` remaining — omitted here since the next step claims one of them.)

```
$ docker exec redis-modern-data-models redis-cli XCLAIM stream:pulse:orders:practice grp:practice consumer-b 0 1791591038707-0
1) 1) "1791591038707-0"
   2) 1) "event" 2) "evt400" 3) "user" 4) "u5" 5) "qty" 6) "2"
```
`consumer-b` now owns the entry `consumer-a` never acknowledged — `XCLAIM` reassigns ownership in the group's pending-entries list without touching the stream itself.

```
$ docker exec redis-modern-data-models redis-cli XREADGROUP GROUP grp:practice consumer-b COUNT 10 STREAMS stream:pulse:orders:practice >
1) 1) "stream:pulse:orders:practice"
   2) 1) 1) "1791591038845-0"
         2) 1) "event" 2) "evt600" 3) "user" 4) "u3" 5) "qty" 6) "1"
```
Only the **fourth** order comes back — the one nobody in the group had been given yet (`>` only ever delivers undelivered entries). It wasn't included in step 2's read because `consumer-a` only asked for `COUNT 3`.

```
$ docker exec redis-modern-data-models redis-cli XAUTOCLAIM stream:pulse:orders:practice grp:practice consumer-c 0 0
1) "0-0"
2) 1) 1) "1791591038707-0" 2) 1) "event" 2) "evt400" ...
   2) 1) "1791591038778-0" 2) 1) "event" 2) "evt600" ...
   3) 1) "1791591038845-0" 2) 1) "event" 2) "evt600" ...
```
`consumer-c` claims all three still-pending entries in one call (the ones held by `consumer-b` from steps 5-6, plus the still-unacked third order from step 2) — this is the "sweep up anything stuck" call a recovery job would run on a schedule, instead of naming IDs one at a time like `XCLAIM`.

```
$ docker exec redis-modern-data-models redis-cli XACK stream:pulse:orders:practice grp:practice 1791591038707-0 1791591038778-0 1791591038845-0
(integer) 3
$ docker exec redis-modern-data-models redis-cli XPENDING stream:pulse:orders:practice grp:practice
1) (integer) 0
2) (nil)
3) (nil)
4) (nil)
```
All four orders are now acknowledged exactly once, across three different consumer identities, with no entry lost and none double-counted — the guarantee a consumer group exists to provide.
