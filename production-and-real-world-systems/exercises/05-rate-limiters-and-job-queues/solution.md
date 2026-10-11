# Solution 05 — Rate Limiters & Job Queues

**Step 1 — reusable rate limiter:**

```
$ python3 -c "
import sys, time; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())

class FixedWindowLimiter:
    def __init__(self, r, prefix='ratelimit:fixed', limit=3, window_s=30):
        self.r, self.prefix, self.limit, self.window_s = r, prefix, limit, window_s
    def allow(self, key):
        window = int(time.time() // self.window_s)
        k = f'{self.prefix}:{key}:w{window}'
        count = self.r.incr(k)
        if count == 1:
            self.r.expire(k, self.window_s)
        return count <= self.limit

limiter = FixedWindowLimiter(r, limit=3)
print('allow() for 5 calls (limit=3):', [limiter.allow('agent:7') for _ in range(5)])
"
allow() for 5 calls (limit=3): [True, True, True, False, False]
```

The third call still returns `True` (count reaches exactly the limit) and the fourth is the first rejection — the same off-by-one-sensitive boundary the Level 2 solution called out, now wrapped in a class instead of inline commands.

**Step 2 — reliable queue, happy path:**

```
$ python3 -c "
import sys, json; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())

def enqueue_notification(r, agent_id, payload):
    r.lpush('pulse:queue:notifications:pending', json.dumps({'agent_id': agent_id, **payload}))

def process_notifications(r, consumer='worker-1'):
    processed = []
    while True:
        item = r.lmove('pulse:queue:notifications:pending',
                        f'pulse:queue:notifications:processing:{consumer}', 'RIGHT', 'LEFT')
        if item is None:
            break
        processed.append(json.loads(item))
        r.lrem(f'pulse:queue:notifications:processing:{consumer}', 1, item)
    return processed

enqueue_notification(r, 'agent:7', {'event': 'vip_claim_confirmed'})
enqueue_notification(r, 'agent:9', {'event': 'vip_claim_confirmed'})
print('pending before processing:', r.llen('pulse:queue:notifications:pending'))
print('processed:', process_notifications(r))
print('pending after processing:', r.llen('pulse:queue:notifications:pending'))
"
pending before processing: 2
processed: [{'agent_id': 'agent:7', 'event': 'vip_claim_confirmed'}, {'agent_id': 'agent:9', 'event': 'vip_claim_confirmed'}]
pending after processing: 0
```

**Step 3 — crash recovery:**

```
$ python3 -c "
# ... r, enqueue_notification defined as above ...
enqueue_notification(r, 'agent:11', {'event': 'test_crash'})
stuck = r.lmove('pulse:queue:notifications:pending', 'pulse:queue:notifications:processing:worker-2', 'RIGHT', 'LEFT')
print('moved to processing (worker-2 crashed before acking):', stuck)
print('still recoverable:', r.lrange('pulse:queue:notifications:processing:worker-2', 0, -1))
"
moved to processing (worker-2 crashed before acking): {"agent_id": "agent:11", "event": "test_crash"}
still recoverable: ['{"agent_id": "agent:11", "event": "test_crash"}']
```

The item was never deleted — only moved — so it's sitting in `pulse:queue:notifications:processing:worker-2` exactly as it would be after a real crash, available for a recovery sweep to re-queue.

**Step 4 — production-readiness gap and whether it's worth closing:**

The single biggest gap versus BullMQ/Celery is automatic **stalled-job recovery**: this lesson's version requires something to periodically scan every `processing:<consumer>` list and notice an item has been sitting there too long — that sweep doesn't exist yet, it's just "the data is there if you build one." For Pulse's VIP-claim notification job specifically — low volume, no scheduling, no priority tiers — the hand-rolled version plus a small cron-style sweep is proportionate; adopting a whole framework for one simple job type would be paying for retries-with-backoff, delayed jobs, and a dashboard UI Pulse doesn't currently need.

**Step 5 — when to reach for Streams instead:**

Reach for Streams + consumer groups instead of this list-based pattern as soon as more than one independent consumer needs to process the *same* events (e.g. both a notification sender and a fraud-detection service need to see every VIP-claim event) — a plain list hands each item to exactly one consumer, while a Stream with multiple consumer groups lets every group see the full log independently.
