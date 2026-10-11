# Solution — Capstone: Pulse Goes Live

The complete `pulse_capstone.py` (replacing every `NotImplementedError` stub):

```python
import json
import time
import uuid

import redis

REDIS_HOST = "localhost"
REDIS_PORT = 6410

CACHE_TTL_S = 30
LOCK_TTL_MS = 2000
LOCK_SPIN_ATTEMPTS = 50
LOCK_SPIN_DELAY_S = 0.01
RATE_LIMIT = 3
RATE_WINDOW_S = 30


def get_pool(max_connections=10):
    return redis.ConnectionPool(
        host=REDIS_HOST, port=REDIS_PORT, decode_responses=True, max_connections=max_connections
    )


def cache_aside_get_event(pool, event_id):
    r = redis.Redis(connection_pool=pool)
    cache_key = f"pulse:cache:event:{event_id}"
    cached = r.hgetall(cache_key)
    if cached:
        return cached, "HIT"
    db_key = f"pulse:db:event:{event_id}"
    data = r.hgetall(db_key)
    if data:
        r.hset(cache_key, mapping=data)
        r.expire(cache_key, CACHE_TTL_S)
    return data, "MISS"


def write_through_update_price(pool, event_id, new_price):
    r = redis.Redis(connection_pool=pool)
    r.hset(f"pulse:db:event:{event_id}", "price", new_price)
    r.hset(f"pulse:cache:event:{event_id}", "price", new_price)


def try_claim_vip_slot(pool, event_id, agent_id):
    r = redis.Redis(connection_pool=pool)
    lock_key = f"pulse:lock:vip-claim:{event_id}"
    token = str(uuid.uuid4())

    acquired = False
    for _ in range(LOCK_SPIN_ATTEMPTS):
        if r.set(lock_key, token, nx=True, px=LOCK_TTL_MS):
            acquired = True
            break
        time.sleep(LOCK_SPIN_DELAY_S)

    if not acquired:
        return {"success": False, "reason": "lock_timeout", "fencing_token": None, "agent_id": agent_id}

    try:
        fencing_token = r.incr(f"pulse:fencing:event:{event_id}")
        db_key = f"pulse:db:event:{event_id}"
        remaining = int(r.hget(db_key, "vip_slots_remaining") or 0)
        if remaining <= 0:
            return {"success": False, "reason": "sold_out", "fencing_token": fencing_token, "agent_id": agent_id}
        r.hincrby(db_key, "vip_slots_remaining", -1)
        r.hset(db_key, "last_fencing_token", fencing_token)
        claim_id = str(uuid.uuid4())
        r.hset(f"pulse:db:claim:{event_id}", agent_id, claim_id)
        return {
            "success": True, "reason": "claimed", "fencing_token": fencing_token,
            "agent_id": agent_id, "claim_id": claim_id,
        }
    finally:
        r.delex(lock_key, ifeq=token)


def rate_limited(pool, agent_id):
    r = redis.Redis(connection_pool=pool)
    window = int(time.time() // RATE_WINDOW_S)
    key = f"pulse:ratelimit:vip-claim:{agent_id}:w{window}"
    count = r.incr(key)
    if count == 1:
        r.expire(key, RATE_WINDOW_S)
    return count > RATE_LIMIT


def enqueue_notification(pool, claim_result):
    if not claim_result.get("success"):
        return False
    r = redis.Redis(connection_pool=pool)
    payload = json.dumps({
        "agent_id": claim_result["agent_id"], "claim_id": claim_result["claim_id"],
        "event": "vip_claim_confirmed",
    })
    r.lpush("pulse:queue:notifications:pending", payload)
    return True


def process_notifications(pool, consumer="capstone-worker"):
    r = redis.Redis(connection_pool=pool)
    processed = []
    processing_key = f"pulse:queue:notifications:processing:{consumer}"
    while True:
        item = r.lmove("pulse:queue:notifications:pending", processing_key, "RIGHT", "LEFT")
        if item is None:
            break
        data = json.loads(item)
        r.set(f"pulse:notified:{data['agent_id']}", data["claim_id"])
        r.lrem(processing_key, 1, item)
        processed.append(data)
    return processed
```

**Why the fencing token is checked against the DB hash, not just trusted from the lock:** `try_claim_vip_slot` writes `last_fencing_token` onto `pulse:db:event:<id>` — the *resource* — every time a claim actually commits. This is the mechanism Lesson 04 describes: the lock's safe release (`DELEX ... IFEQ`) only protects against a caller deleting a lock it doesn't own; it says nothing about whether a delayed caller might still try to act *after* its lock has already expired and been reassigned. Checking the resource's own recorded token is what would let a real system reject such a stale write outright — here, `verify.sh` confirms the mechanism is wired correctly by checking the DB's `last_fencing_token` matches the winning claim's returned token, which is only true if the resource-side bookkeeping is actually happening, not just the lock's mutual exclusion.

**Why `accepted` must be exactly `3`, not just "fewer than the hammer count":** An off-by-one here (e.g. checking `count >= RATE_LIMIT` instead of `count > RATE_LIMIT`) would silently allow one extra request through every single window, every single time — in production that's not a cosmetic bug, it's a rate limiter that's permanently wrong by a fixed, exploitable margin an attacker could learn and rely on. Asserting the exact count, not just "fewer than unlimited," is what actually catches that class of bug instead of passing on a limiter that merely limits *something*.

**Verified end-to-end run** (your own `race_runner.py` output's specific IDs/tokens will differ — fencing tokens and the identity of the winning agent are nondeterministic across runs by design):

```
$ python3 seed_pulse.py
seeded pulse:db:event:vip1 with 1 VIP slot remaining

$ python3 race_runner.py lock_race
{"agent:alice": {"success": true, "reason": "claimed", "fencing_token": 1, "agent_id": "agent:alice", "claim_id": "1974fc31-83f6-4978-9a0a-7f1958076bb8"}, "agent:bob": {"success": false, "reason": "sold_out", "fencing_token": 2, "agent_id": "agent:bob"}}

$ docker exec redis-observability redis-cli HGET pulse:db:event:vip1 vip_slots_remaining
"0"
$ docker exec redis-observability redis-cli HGET pulse:db:event:vip1 last_fencing_token
"1"
```

The winning agent's `fencing_token` (`1`) matches `last_fencing_token` on the DB hash exactly — the resource recorded which attempt actually committed, independent of the lock itself.

```
$ python3 race_runner.py rate_limit_hammer
{"accepted": 3, "rejected": 7, "outcomes": [false, false, false, true, true, true, true, true, true, true]}
```

`false` means "not rate-limited" (allowed) in this capstone's return convention — the first 3 calls succeed, every call after that is rejected.

```
$ bash verify.sh
PASS: redis-observability responds to PING
PASS: Prometheus reports redis_up == 1
PASS: cache-aside TTL is set and bounded (0 < ttl <= 30)
PASS: write-through updates the cache immediately
PASS: exactly one of two concurrent claims succeeded
PASS: vip_slots_remaining is exactly 0 after the race (no oversell)
PASS: the two fencing tokens differ (the counter actually incremented)
PASS: the DB's last_fencing_token matches the winning claim's token
PASS: rate limiter accepted exactly the configured limit (3)
PASS: rate limiter rejected at least one call beyond the limit
PASS: notification queued (pending list non-empty) immediately post-claim
PASS: pending list empty after processing
PASS: notified marker key exists for the winning agent
PASS: memo.md contains all required headings
PASS: redis_commands_processed_total increased during this run (the dashboard would show it)

Results: 15 passed, 0 failed
```

Confirmed stable across 6 consecutive runs during this module's build, including the two checks with genuine thread-timing sensitivity (the lock race and the rate-limiter hammer) — neither flaked.

**Stretch — Active-Active, briefly:** Pulse's architecture as built across this course would need real changes before it could run Active-Active across two regions, not just a managed-service upgrade: `try_claim_vip_slot`'s lock-and-decrement logic assumes one consistent view of `vip_slots_remaining` to check against, but Active-Active's CRDT merge semantics are designed for conflict-free convergence of independent writes, not for enforcing "exactly one of these two concurrent operations may succeed" across regions — the VIP-slot-claim invariant this whole capstone protects is precisely the kind of cross-region mutual-exclusion guarantee CRDTs don't provide out of the box. A real Active-Active migration would need Pulse to either accept a different invariant (e.g., a small per-region slot allocation reconciled after the fact) or move slot-claiming's correctness requirement to a system better suited to cross-region coordination — exactly the kind of tradeoff Lesson 08's framework exists to surface before building it, not after.
