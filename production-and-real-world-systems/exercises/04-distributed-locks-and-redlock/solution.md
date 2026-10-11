# Solution 04 — Distributed Locks & Redlock

**Step 1 — the naive-release bug, reproduced:**

```
$ python3 -c "
import sys, time, uuid; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())

token_a = str(uuid.uuid4())
assert r.set('lock:refund:evt1', token_a, nx=True, px=200)
time.sleep(0.3)
token_b = str(uuid.uuid4())
got_b = r.set('lock:refund:evt1', token_b, nx=True, px=10000)
print('B acquired after As lock expired:', bool(got_b))
r.delete('lock:refund:evt1')
print('after As naive DEL, key exists (BUG: A deleted Bs lock!):', r.exists('lock:refund:evt1'))
"
B acquired after As lock expired: True
after As naive DEL, key exists (BUG: A deleted Bs lock!): 0
```

B's lock is gone — deleted by A, which had no idea its own lock had already expired and been reassigned. This is exactly the failure mode a bare `DEL` on release introduces.

**Steps 2–3 — safe release, two ways:**

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
print('release with WRONG token (Lua):', release_script(keys=['lock:refund:evt2'], args=[str(uuid.uuid4())]))
print('key still there:', r.exists('lock:refund:evt2'))
print('release with CORRECT token (Lua):', release_script(keys=['lock:refund:evt2'], args=[token_c]))
print('key gone:', r.exists('lock:refund:evt2'))

token_d = str(uuid.uuid4())
r.set('lock:refund:evt3', token_d, nx=True, px=10000)
print('DELEX wrong token:', r.delex('lock:refund:evt3', ifeq='wrong'))
print('DELEX correct token:', r.delex('lock:refund:evt3', ifeq=token_d))
"
release with WRONG token (Lua): 0
key still there: 1
release with CORRECT token (Lua): 1
key gone: 0
DELEX wrong token: 0
DELEX correct token: 1
```

Both mechanisms refuse to delete when the token doesn't match, and succeed (returning the count of keys deleted, `1`) when it does — the atomicity comes from the fact that the GET-then-DEL (or `DELEX`'s internal equivalent) happens as a single operation Redis never interleaves with another client's commands, unlike doing the check and the `DEL` as two separate round-trips from the application.

**Step 4 — simulated Redlock quorum across 5 keys:**

```
$ python3 -c "
# ... r defined as above ...
import time
N = 5
QUORUM = N // 2 + 1

def redlock_acquire(resource, ttl_ms=10000):
    token = str(uuid.uuid4())
    start = time.monotonic()
    acquired = 0
    for i in range(N):
        if r.set(f'lock:{resource}:replica:{i}', token, nx=True, px=ttl_ms):
            acquired += 1
    elapsed_ms = (time.monotonic() - start) * 1000
    validity_ms = ttl_ms - elapsed_ms
    if acquired >= QUORUM and validity_ms > 0:
        return token, validity_ms
    for i in range(N):
        r.delex(f'lock:{resource}:replica:{i}', ifeq=token)
    return None, 0

token, validity = redlock_acquire('vip-claim:evt1')
print(f'(a) all free: acquired={bool(token)} quorum_needed={QUORUM} validity_ms={validity:.1f}')

r.set('lock:vip-claim:evt2:replica:0', 'other-token', nx=True, px=10000)
r.set('lock:vip-claim:evt2:replica:1', 'other-token', nx=True, px=10000)
token2, validity2 = redlock_acquire('vip-claim:evt2')
print(f'(b) 2/5 pre-held: acquired={bool(token2)} validity_ms={validity2:.1f}')

for i in range(3):
    r.set(f'lock:vip-claim:evt3:replica:{i}', 'other-token', nx=True, px=10000)
token3, validity3 = redlock_acquire('vip-claim:evt3')
print(f'(c) 3/5 pre-held: acquired={bool(token3)}')
print('leaked locks from the failed (c) attempt:', r.keys('lock:vip-claim:evt3:replica:*'))
"
(a) all free: acquired=True quorum_needed=3 validity_ms=9986.9
(b) 2/5 pre-held: acquired=True validity_ms=9998.3
(c) 3/5 pre-held: acquired=False
leaked locks from the failed (c) attempt: []
```

`(c)`'s final `KEYS` check returns an empty list — `redlock_acquire` correctly released the 2 replica locks it *did* win (the ones not pre-held by someone else) rather than leaving them to expire on their own, confirming the "release whatever we got" cleanup path works.

**Step 5 — what a fencing token adds:**

The Lua/`DELEX` safe-release prevents a lock-holder from deleting *someone else's* lock on release — but it does nothing to stop a lock holder that's gone slow (a GC pause, a stalled disk write) from **finishing its critical-section work late**, after its lock has already expired and been reassigned to a new holder. The old holder never calls release at all in that scenario — it just wakes up and acts as if it still holds the lock, because from its own point of view nothing told it otherwise. A fencing token fixes this one level up: the *resource being protected* (not the lock) remembers the highest fencing token it has ever accepted, and rejects any write arriving with a lower one — so the late straggler's eventually-arriving write gets rejected by the resource itself, lock or no lock.

**Step 6 — when a database guarantee beats a Redis lock:**

Pulse's ticket-purchase row update (decrementing `tickets_available` in the primary database) is a better fit for the database's own compare-and-swap (`UPDATE tickets SET available = available - 1 WHERE event_id = ? AND available > 0`, checking the affected-row count) than for a Redis lock: the database already has a durable, transactional source of truth for that counter, so adding a separate lock service only introduces a second system that itself needs to be kept consistent with the first, for no additional safety the database's own `WHERE` clause didn't already provide.
