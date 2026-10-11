# Lesson 04 — Distributed Locks & Redlock

## Learning Objectives

By the end of this lesson you can:
- Implement the single-instance `SET resource token NX PX ttl` lock and explain why a naive, unconditional `DEL` on release is a real bug, not a theoretical one
- Release a lock safely with an atomic compare-and-delete (the classic Lua script, and Redis 8.4's native `DELEX ... IFEQ`)
- Explain the Redlock algorithm's quorum mechanic across N independent masters
- State Martin Kleppmann's core criticism of Redlock and antirez's response, and explain what a **fencing token** adds that a bare lock can't give you
- Decide, for a given use case, whether a Redis lock is an appropriate tool at all

## Concept

Lesson 03 ended on a dangling problem: two concurrent cache-aside misses racing to decrement the same counter. A **distributed lock** is Redis's answer — one caller acquires a key that represents "I'm doing this right now," everyone else backs off until it's released. Getting this *safely* right is subtler than it looks.

### The single-instance lock, and the bug in releasing it naively

```
$ python3 -c "
import sys, time, uuid; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())

token_a = str(uuid.uuid4())
assert r.set('lock:refund:evt1', token_a, nx=True, px=200)   # A acquires, 200ms TTL
time.sleep(0.3)                                              # A stalls past its own TTL (GC pause, slow I/O...)
token_b = str(uuid.uuid4())
got_b = r.set('lock:refund:evt1', token_b, nx=True, px=10000) # B now legitimately acquires
print('B acquired after As lock expired:', bool(got_b))
r.delete('lock:refund:evt1')                                  # A, unaware it timed out, releases naively
print('after As naive DEL, key exists (BUG: A deleted Bs lock!):', r.exists('lock:refund:evt1'))
"
B acquired after As lock expired: True
after As naive DEL, key exists (BUG: A deleted Bs lock!): 0
```

That last line is the bug: A's process stalled past its own TTL, B correctly acquired the now-expired lock, and A's unconditional `DEL` destroyed B's *valid* lock without ever checking whether it still owned it. Now two callers believe they hold the lock simultaneously — the exact failure a lock exists to prevent, caused by the lock's own release logic.

The fix: release must be an **atomic compare-and-delete** — "delete this key, but only if its value still equals the token I was given when I acquired it." Two ways to do that on this lab's `redis:8.10.1`:

**The classic way — a Lua script** (atomic because the whole script runs as one unit, never interleaved with another client's commands):

```
$ python3 -c "
# ... r defined as above ...
RELEASE_LUA = '''
if redis.call(\"GET\", KEYS[1]) == ARGV[1] then
    return redis.call(\"DEL\", KEYS[1])
else
    return 0
end
'''
release_script = r.register_script(RELEASE_LUA)
import uuid
token_c = str(uuid.uuid4())
r.set('lock:refund:evt2', token_c, nx=True, px=10000)
print('release with WRONG token:', release_script(keys=['lock:refund:evt2'], args=[str(uuid.uuid4())]))
print('key still there:', r.exists('lock:refund:evt2'))
print('release with CORRECT token:', release_script(keys=['lock:refund:evt2'], args=[token_c]))
"
release with WRONG token: 0
key still there: 1
release with CORRECT token: 1
```

**New in Redis 8.4 — `DELEX key IFEQ value`**, which does exactly the same thing as a first-class command, no Lua required:

```
$ python3 -c "
# ... r defined as above ...
import uuid
token_d = str(uuid.uuid4())
r.set('lock:refund:evt3', token_d, nx=True, px=10000)
print('DELEX wrong token:', r.delex('lock:refund:evt3', ifeq='wrong'))
print('DELEX correct token:', r.delex('lock:refund:evt3', ifeq=token_d))
"
DELEX wrong token: 0
DELEX correct token: 1
```

`r.delex(...)` is marked `@experimental_method()` in `redis-py` 8.1.0 as of this writing — it works, but expect its signature to still be settling; the Lua version is the more battle-tested choice if you need this in production *today*, while `DELEX` is worth tracking as it stabilizes.

### Redlock — spreading the lock across N independent masters

A single-instance lock has a single point of failure: if that one Redis node goes down while holding a lock, every other caller is stuck waiting out the TTL with no way to know if the lock-holder is still alive. **Redlock** (proposed by antirez, Redis's original author) addresses this by acquiring the *same* lock against **N independent Redis masters** (classically N=5) and requiring a **majority** (⌈N/2⌉+1, so 3 of 5) to succeed, within the lock's validity window:

```python
N = 5
QUORUM = N // 2 + 1  # 3

def redlock_acquire(resource, ttl_ms=10000):
    token = str(uuid.uuid4())
    start = time.monotonic()
    acquired = 0
    for i in range(N):
        if r.set(f"lock:{resource}:replica:{i}", token, nx=True, px=ttl_ms):
            acquired += 1
    elapsed_ms = (time.monotonic() - start) * 1000
    validity_ms = ttl_ms - elapsed_ms
    if acquired >= QUORUM and validity_ms > 0:
        return token, validity_ms
    for i in range(N):
        r.delex(f"lock:{resource}:replica:{i}", ifeq=token)  # release whatever we did get
    return None, 0
```

> **This lab runs one Redis node, not five.** The code above uses 5 *keys* on the same instance to demonstrate the quorum-counting mechanic — acquire against each "replica," count successes, check the elapsed time didn't eat the whole validity window — but it is **not** a real test of Redlock's actual value proposition, which is tolerating the *independent* failure of up to 2 of 5 separate machines. A real Redlock deployment needs 5 genuinely independent Redis processes (different hosts, ideally different failure domains), and most teams reach for a managed/library implementation (e.g. the `redis-py` ecosystem's `Redlock` helper libraries, or Redis Software's built-in RLEC locking) rather than hand-rolling the client-side loop above.

```
$ python3 -c "
# ... redlock_acquire defined as above ...
token, validity = redlock_acquire('vip-claim:evt1')
print(f'acquired={bool(token)} quorum_needed={QUORUM} validity_ms={validity:.1f}')
r.set('lock:vip-claim:evt2:replica:0', 'other-token', nx=True, px=10000)
r.set('lock:vip-claim:evt2:replica:1', 'other-token', nx=True, px=10000)
token2, validity2 = redlock_acquire('vip-claim:evt2')
print(f'with 2/5 pre-held, acquired={bool(token2)} validity_ms={validity2:.1f}')
for i in range(3):
    r.set(f'lock:vip-claim:evt3:replica:{i}', 'other-token', nx=True, px=10000)
token3, validity3 = redlock_acquire('vip-claim:evt3')
print(f'with 3/5 pre-held, acquired={bool(token3)}')
"
acquired=True quorum_needed=3 validity_ms=9986.9
with 2/5 pre-held, acquired=True validity_ms=9998.3
with 3/5 pre-held, acquired=False
```

With 2 of 5 replicas already held by someone else, quorum (3) is still reachable on the remaining 3 — lock acquired. With 3 of 5 already held, only 2 are free — quorum of 3 is impossible, and `redlock_acquire` correctly reports failure and cleans up the partial acquisitions it did make (never leaving stray locks behind on the replicas it *did* win).

### The Kleppmann critique, and fencing tokens

In 2016, Martin Kleppmann [published a detailed critique](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html) arguing Redlock is unsafe for any use case where the lock exists to enforce **correctness** (e.g. "only one process may write to this file") rather than just **efficiency** (e.g. "don't bother running this expensive job twice"). His core point: *any* lock based purely on timeouts can't distinguish "the lock holder died" from "the lock holder is just slow" (a GC pause, a scheduling stall, a slow disk write) — and a slow-but-still-alive holder can wake up after its lock has already been reassigned to someone else and proceed to stomp on the new holder's work, exactly like the naive-`DEL` bug above, just one level higher up. [antirez's response](http://antirez.com/news/101) argues Redlock's validity-time check (the `elapsed_ms`/`validity_ms` arithmetic above) bounds this risk to pathological clock/scheduling behavior, not ordinary operation — but concedes the lock alone still doesn't *prove* mutual exclusion to whatever system the lock is protecting.

The missing piece both authors agree on: a **fencing token** — a number that strictly increases every time the lock is granted, which the protected resource (not just the lock) checks and rejects if it ever goes backwards. A lock holder that wakes up late and tries to act with a stale, lower fencing token gets rejected *by the resource itself*, not just by hoping the lock held. This lesson's exercise and the capstone both have `try_claim_vip_slot`-style functions return a fencing token for exactly this reason — the Redis lock narrows the race window, the fencing token is what actually makes a late straggler's write provably safe to ignore.

**When not to reach for a Redis lock at all:** if the actual correctness guarantee you need is "exactly one database row gets updated," your database's own transaction isolation (a `SELECT ... FOR UPDATE`, a unique constraint, a compare-and-swap on a version column) is very often a simpler and more trustworthy tool than coordinating a separate lock service against a separate failure domain. Reach for a Redis lock when the resource you're protecting genuinely has no transactional guarantee of its own (e.g. a side effect against a third-party API, or coordinating across multiple independent services that don't share a database) — not as a reflex for every "only once" requirement.

## Official Docs

- [Distributed Locks with Redis](https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/)
- [SET](https://redis.io/docs/latest/commands/set/)
- [DELEX](https://redis.io/docs/latest/commands/delex/)
- [EVAL / Lua scripting](https://redis.io/docs/latest/develop/interact/programmability/eval-intro/)

## Exercise

→ [exercises/04-distributed-locks-and-redlock/exercise.md](../exercises/04-distributed-locks-and-redlock/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU102: Redis for Developers" covers the `SET NX` lock pattern; Kleppmann's and antirez's linked posts above are the deeper, canonical reading for Redlock's actual safety tradeoffs.
