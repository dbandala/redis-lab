# Lesson 05 — Rate Limiters & Job Queues

## Learning Objectives

By the end of this lesson you can:
- Package Level 2's fixed-window rate-limiting counter into a reusable, parameterized class suitable for a middleware layer
- Implement the reliable-queue pattern (`LPUSH` + `LMOVE`) so an in-flight job surviving a worker crash is still recoverable, not lost
- Explain what BullMQ and Celery add on top of raw Redis primitives, and why you'd reach for one of them instead of hand-rolling further
- Explain when Streams + consumer groups (Level 3) are the better fit than a plain list-based queue

## Concept

Level 2, Lesson 03 built a fixed-window counter (`INCR` + `EXPIRE ... NX`) and a sliding-window log (`ZADD` + `ZREMRANGEBYSCORE`) as raw commands. Production code doesn't call those commands inline at every call site — it wraps them in a small, reusable piece of middleware every request path can share.

### A reusable rate limiter

```python
class FixedWindowLimiter:
    def __init__(self, r, prefix="ratelimit:fixed", limit=3, window_s=30):
        self.r, self.prefix, self.limit, self.window_s = r, prefix, limit, window_s

    def allow(self, key):
        window = int(time.time() // self.window_s)
        k = f"{self.prefix}:{key}:w{window}"
        count = self.r.incr(k)
        if count == 1:
            self.r.expire(k, self.window_s)
        return count <= self.limit
```

```
$ python3 -c "
import sys, time; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())
# ... FixedWindowLimiter defined as above ...
limiter = FixedWindowLimiter(r, limit=3)
print('allow() for 5 calls (limit=3):', [limiter.allow('agent:7') for _ in range(5)])
"
allow() for 5 calls (limit=3): [True, True, True, False, False]
```

This is exactly the same `ratelimit:fixed:*` keyspace from Level 2 — nothing about the Redis-side mechanics changed. What changed is that it's now a class any request handler can instantiate once (sharing the same connection pool from Lesson 02) and call `.allow(agent_id)` against, instead of re-deriving the window-key arithmetic at every call site. This is the actual "architecture" in "architectural patterns" — the same primitive, wrapped so it's safe and consistent to reuse.

### The reliable-queue pattern

A naive job queue is just `LPUSH` to add work and `RPOP` to take it — but `RPOP` removes the item the instant a worker picks it up. If that worker **crashes** after popping but before finishing the job, the job is gone: nobody will ever retry it. The fix, predating Streams and still common where Streams would be overkill, is **`LMOVE`** (or its blocking form, `BLMOVE`): move the item atomically from the pending list to a per-worker **processing** list, instead of deleting it outright. The item is never not-somewhere — it's always sitting in exactly one of the two lists:

```python
def enqueue_notification(r, agent_id, payload):
    r.lpush("pulse:queue:notifications:pending", json.dumps({"agent_id": agent_id, **payload}))

def process_notifications(r, consumer="worker-1"):
    processed = []
    while True:
        item = r.lmove("pulse:queue:notifications:pending",
                        f"pulse:queue:notifications:processing:{consumer}", "RIGHT", "LEFT")
        if item is None:
            break
        processed.append(json.loads(item))
        r.lrem(f"pulse:queue:notifications:processing:{consumer}", 1, item)  # ack: remove once done
    return processed
```

```
$ python3 -c "
# ... r, enqueue_notification, process_notifications defined as above ...
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

Now the crash scenario — a worker moves an item into its processing list but dies before the `LREM` ack:

```
$ python3 -c "
# ... r, enqueue_notification defined as above ...
enqueue_notification(r, 'agent:11', {'event': 'test_crash'})
stuck = r.lmove('pulse:queue:notifications:pending', 'pulse:queue:notifications:processing:worker-2', 'RIGHT', 'LEFT')
print('moved to processing (worker-2 crashed before acking):', stuck)
print('still recoverable in processing list:', r.lrange('pulse:queue:notifications:processing:worker-2', 0, -1))
"
moved to processing (worker-2 crashed before acking): {"agent_id": "agent:11", "event": "test_crash"}
still recoverable in processing list: ['{"agent_id": "agent:11", "event": "test_crash"}']
```

The job is sitting right there in `processing:worker-2`, recoverable by a monitoring process that periodically scans per-worker processing lists for items older than some threshold and re-queues them — this is the reliable-queue pattern's whole point: a crash loses the worker, never the job.

### What BullMQ and Celery add

BullMQ (Node.js) and Celery (Python, though it supports other brokers too) are built **on top of** Redis primitives much like the code above, but productionize everything this lesson's hand-rolled version leaves as an exercise for the reader:

| Capability | Hand-rolled (this lesson) | BullMQ / Celery |
|---|---|---|
| At-least-once delivery via a processing list | Yes (shown above) | Yes, plus automatic stalled-job recovery (a background sweeper, not a manual scan) |
| Retries with backoff | Not implemented | Built in, configurable per job |
| Delayed / scheduled jobs | Not implemented | Built in (`ZADD`-backed delay queues internally) |
| Priority queues | Not implemented | Built in |
| Dashboards / observability | Only via Lesson 01's Grafana panels, generically | Purpose-built UI (Bull Board for BullMQ, Flower for Celery) |
| Dependency | None — raw `redis-py` | An additional library + worker process model to run and operate |

The decision isn't "raw Redis vs. a framework" in the abstract — it's whether you need more than one or two rows of that table. A single background job type with simple retry needs is often fine hand-rolled (as above); a system with many job types, scheduling, priorities, and a team that needs visibility into queue health usually earns its keep with BullMQ or Celery.

### Streams vs. this lesson's list-based queue

Level 3, Lesson 07 already covered **Streams + consumer groups** — `XADD`, `XREADGROUP`, `XACK` — which is Redis's own modern answer to the same reliable-delivery problem, and is usually the better default today: consumer groups give you multiple independent consumer *groups* over the same log (an audit trail, a search indexer, and a notification sender can all read the same stream independently), automatic per-consumer tracking of what's been delivered-but-not-acked (`XPENDING`, `XCLAIM`), and a durable, replayable log rather than a list that's empty once drained. The `LPUSH`/`LMOVE` pattern in this lesson is worth knowing because it's simpler, lighter-weight, and still extremely common in existing codebases — but for new work, reach for Streams unless you have a specific reason not to (e.g. a very simple single-consumer job queue where Streams' extra structure is pure overhead).

## Official Docs

- [Redis as a message queue](https://redis.io/docs/latest/develop/use/patterns/)
- [LMOVE](https://redis.io/docs/latest/commands/lmove/)
- [BLMOVE](https://redis.io/docs/latest/commands/blmove/)
- [LREM](https://redis.io/docs/latest/commands/lrem/)

## Exercise

→ [exercises/05-rate-limiters-and-job-queues/exercise.md](../exercises/05-rate-limiters-and-job-queues/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU205: Streaming Data" revisits consumer groups in depth; BullMQ's and Celery's own documentation are the right next stop for actually operating either in production.
