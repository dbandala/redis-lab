# Solution 08 — Bloom & Cuckoo Filters

```
$ docker exec redis-modern-data-models redis-cli BF.RESERVE webhooks:seen:practice 0.02 500
OK
$ docker exec redis-modern-data-models redis-cli BF.MADD webhooks:seen:practice whk_a1 whk_b2 whk_c3
1) (integer) 1
2) (integer) 1
3) (integer) 1
```

```
$ docker exec redis-modern-data-models redis-cli BF.EXISTS webhooks:seen:practice whk_a1
(integer) 1
$ docker exec redis-modern-data-models redis-cli BF.EXISTS webhooks:seen:practice whk_never_sent
(integer) 0
```
`whk_a1` reads back as present (`1`); the never-added ID reads back as absent (`0`), as expected.

```
$ docker exec redis-modern-data-models redis-cli BF.MEXISTS webhooks:seen:practice whk_a1 whk_b2 whk_c3 whk_never_sent
1) (integer) 1
2) (integer) 1
3) (integer) 1
4) (integer) 0
```
Matches step 2 exactly — the three added IDs all report present, the untouched one reports absent, all in one round trip.

```
$ docker exec redis-modern-data-models redis-cli BF.ADD webhooks:seen:practice whk_a1
(integer) 0
```
`0` means `whk_a1` was already in the filter — `BF.ADD`'s return value *is* the dedup check. A webhook handler can call `BF.ADD` once per incoming webhook: a `1` means "first time, go ahead and fulfill the order"; a `0` means "already handled this one, acknowledge and skip" — no separate `BF.EXISTS` call needed, since `BF.ADD` tells you both facts (whether it was already there, and that it's now recorded) in a single atomic command.

```
$ docker exec redis-modern-data-models redis-cli CF.RESERVE redeemed:evt300:practice 200
OK
$ docker exec redis-modern-data-models redis-cli CF.ADDNX redeemed:evt300:practice TCK-1001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.ADDNX redeemed:evt300:practice TCK-1002
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.ADDNX redeemed:evt300:practice TCK-1001
(integer) 0
```
`CF.ADDNX`'s behavior here is the same shape as `BF.ADD`'s in step 4 — `0` for an already-present member, `1` for a new one. The real difference between Bloom and Cuckoo shows up in the next step, not this one.

```
$ docker exec redis-modern-data-models redis-cli CF.DEL redeemed:evt300:practice TCK-1001
(integer) 1
$ docker exec redis-modern-data-models redis-cli CF.EXISTS redeemed:evt300:practice TCK-1001
(integer) 0
$ docker exec redis-modern-data-models redis-cli CF.EXISTS redeemed:evt300:practice TCK-1002
(integer) 1
```
`TCK-1001` is gone, `TCK-1002` is unaffected. This isn't possible with a Bloom filter because there's no `BF.DEL` command — a Bloom filter's bit array has no concept of "which item set which bits," so clearing one item's bits could silently un-set bits other items still depend on, producing false negatives for members that were never removed. A Cuckoo filter stores items in addressable buckets instead, so removing one item's fingerprint doesn't disturb any other item's — which is exactly why it's the right structure whenever "redeemed," "claimed," or "in use" needs to later become "not anymore."
