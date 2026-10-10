# Lesson 08 — Bloom & Cuckoo Filters

## Learning Objectives

By the end of this lesson you can:
- Use a Bloom filter for fast, memory-cheap "have I seen this before?" membership checks with a tunable false-positive rate
- Explain why a Bloom filter can say "maybe seen" but never "definitely not seen when it was" — and why that asymmetry is fine for dedup
- Choose a Cuckoo filter instead when you need to delete a member later

## Concept

Pulse's payment provider retries webhooks — if a response doesn't come back fast enough, the same `payment_confirmed` webhook might arrive twice. Fulfilling an order twice because of a retried webhook is a real bug, not a hypothetical. You could dedupe with a `SET` of every webhook ID ever seen, but that's a set entry's full memory cost held *forever*, for every webhook, just to answer a yes/no question. A **Bloom filter** answers that same question in a fraction of the memory, by trading away a small, tunable chance of a false positive.

`BF.RESERVE` creates a filter sized for an expected item count and error rate:

```
$ docker exec redis-modern-data-models redis-cli BF.RESERVE webhooks:seen 0.01 10000
OK
```

`0.01` = accept up to a 1% false-positive rate; `10000` = expect roughly 10,000 items. `BF.ADD` inserts, `BF.EXISTS` checks membership:

```
$ docker exec redis-modern-data-models redis-cli BF.ADD webhooks:seen whk_8f2a
(integer) 1
$ docker exec redis-modern-data-models redis-cli BF.EXISTS webhooks:seen whk_8f2a
(integer) 1
$ docker exec redis-modern-data-models redis-cli BF.EXISTS webhooks:seen whk_unseen
(integer) 0
```

`BF.MADD`/`BF.MEXISTS` batch multiple items in one round trip:

```
$ docker exec redis-modern-data-models redis-cli BF.MADD webhooks:seen whk_1 whk_2 whk_3
1) (integer) 1
2) (integer) 1
3) (integer) 1
$ docker exec redis-modern-data-models redis-cli BF.MEXISTS webhooks:seen whk_1 whk_99
1) (integer) 1
2) (integer) 0
```

`BF.INFO` reports the filter's actual memory footprint — note how small this is for ten thousand items' worth of capacity:

```
$ docker exec redis-modern-data-models redis-cli BF.INFO webhooks:seen
 1) Capacity
 2) (integer) 10000
 3) Size
 4) (integer) 13888
...
```

~14KB to track up to 10,000 webhook IDs with a 1% false-positive ceiling — nowhere close to what 10,000 real string keys (or set members) would cost. And `BF.ADD` on something already present tells you so, which is exactly the dedup check Pulse needs before fulfilling an order:

```
$ docker exec redis-modern-data-models redis-cli BF.ADD webhooks:seen whk_8f2a
(integer) 0
```

`0` means "already in the filter" — a retried webhook, safe to acknowledge without re-fulfilling the order.

> **The asymmetry that makes this safe.** A Bloom filter can produce a **false positive** ("seen" when it wasn't, at the rate you configured) but never a **false negative** ("not seen" when it was). For dedup, that's exactly the right failure mode: in the rare false-positive case you'd skip re-processing something you actually hadn't seen before (a missed duplicate-looking webhook, rare and usually low-stakes) — you will never accidentally process a true duplicate twice.

What a Bloom filter *can't* do is remove an item — there's no `BF.DEL`, because the structure's math doesn't support it. If you need removal, reach for a **Cuckoo filter** instead — same membership-check idea, slightly larger per item, but deletable:

```
$ docker exec redis-modern-data-models redis-cli CF.RESERVE redeemed:evt100 1000
OK
$ docker exec redis-modern-data-models redis-cli CF.ADD redeemed:evt100 TCK-0001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.EXISTS redeemed:evt100 TCK-0001
(integer) 1
```

`CF.ADDNX` adds only if not already present — useful to detect a duplicate scan-in at the door without a separate `EXISTS` round trip:

```
$ docker exec redis-modern-data-models redis-cli CF.ADDNX redeemed:evt100 TCK-0001
(integer) 0
$ docker exec redis-modern-data-models redis-cli CF.ADDNX redeemed:evt100 TCK-0002
(integer) 1
```

`TCK-0001` was already redeemed, so `CF.ADDNX` correctly refused to add it again (`0`); `TCK-0002` was new (`1`). Now say that ticket gets refunded and should no longer count as redeemed — `CF.DEL` removes it, something a Bloom filter simply cannot do:

```
$ docker exec redis-modern-data-models redis-cli CF.DEL redeemed:evt100 TCK-0001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.EXISTS redeemed:evt100 TCK-0001
(integer) 0
```

## Official Docs

- [BF.RESERVE](https://redis.io/docs/latest/commands/bf.reserve/)
- [BF.ADD](https://redis.io/docs/latest/commands/bf.add/)
- [CF.RESERVE](https://redis.io/docs/latest/commands/cf.reserve/)
- [CF.DEL](https://redis.io/docs/latest/commands/cf.del/)
- [Bloom filter](https://redis.io/docs/latest/develop/data-types/probabilistic/bloom-filter/)
- [Cuckoo filter](https://redis.io/docs/latest/develop/data-types/probabilistic/cuckoo-filter/)

## Exercise

→ [exercises/08-bloom-and-cuckoo-filters/exercise.md](../exercises/08-bloom-and-cuckoo-filters/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Streams" and the probabilistic-data-structures module of "RU102" both cover Bloom/Cuckoo filter sizing tradeoffs in more depth.
