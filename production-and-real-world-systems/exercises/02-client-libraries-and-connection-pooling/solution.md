# Solution 02 — Client Libraries & Connection Pooling

**Steps 1–2 — pooled client, PING, pipelining:**

```
$ python3 -c "
import sys; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
pool = get_pool(max_connections=5)
r = redis.Redis(connection_pool=pool)
print('PING:', r.ping())
pipe = r.pipeline()
for i in range(5):
    pipe.set(f'pulse:test:client:{i}', i)
print('pipeline results:', pipe.execute())
r.delete(*[f'pulse:test:client:{i}' for i in range(5)])
"
PING: True
pipeline results: [True, True, True, True, True]
```

All 5 `SET`s round-tripped once, not five times — confirmed later via Lesson 01's "Commands/sec" dashboard panel if the observability stack is also up: a pipelined batch of 5 writes shows as one small blip, not five separate ticks.

**Step 3 — named, reused connections:**

```
$ docker exec redis-production-and-real-world-systems redis-cli CLIENT LIST | grep pulse-api
id=21 addr=192.168.65.1:26978 laddr=172.20.0.2:6379 fd=23 name=pulse-api age=1 idle=1 flags=N db=0 sub=0 psub=0 ssub=0 multi=-1 watch=0 qbuf=0 qbuf-free=0 argv-mem=0 multi-mem=0 rbs=1024 rbp=0 obl=0 oll=0 omem=0 omem-shared=0 omem-unshared=0 tot-mem=2304 events=r cmd=ping user=default redir=-1 resp=3 lib-name=redis-py lib-ver=8.1.0 io-thread=0 tot-net-in=301 tot-net-out=782 tot-cmds=6 read-events=7 avg-pipeline-len-sum=7 avg-pipeline-len-cnt=7
```

`name=pulse-api` comes straight from `pulse_pool.py`'s `client_name="pulse-api"` argument. `lib-name=redis-py lib-ver=8.1.0` is reported automatically by the client via `CLIENT SETINFO` on connect — useful in a real fleet for spotting which service (and client version) is generating load, straight from `CLIENT LIST`, no extra instrumentation required.

**Step 4 — `BlockingConnectionPool` waits, then fails:**

```
$ python3 -c "
import sys, time; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
from pulse_pool import get_blocking_pool
pool = get_blocking_pool(max_connections=1, timeout=1)
conn1 = pool.get_connection()
t0 = time.time()
try:
    pool.get_connection()
except Exception as e:
    print(f'blocked for {time.time()-t0:.2f}s then raised: {type(e).__name__}: {e}')
"
blocked for 1.00s then raised: ConnectionError: No connection available.
```

**Step 5 — plain `ConnectionPool` fails immediately:**

```
$ python3 -c "
import sys, time; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
from pulse_pool import get_pool
pool = get_pool(max_connections=1)
conn1 = pool.get_connection()
t0 = time.time()
try:
    pool.get_connection()
except Exception as e:
    print(f'failed after {time.time()-t0:.4f}s: {type(e).__name__}: {e}')
"
failed after 0.0000s: MaxConnectionsError: Too many connections
```

`MaxConnectionsError` is actually a subclass of `ConnectionError` (confirmed via `redis.exceptions.MaxConnectionsError.__mro__`), so `except redis.exceptions.ConnectionError` still catches both pool types' failures with one `except` clause — the difference is purely *when* it's raised: the blocking pool trades a bounded wait for a chance that the connection frees up in time; the plain pool fails the instant the ceiling is hit.

**Step 6 — which pool for which role:**

Pulse's HTTP request handlers should use a plain `ConnectionPool`: an HTTP request already has its own timeout budget, and a handler blocking silently on a Redis pool for up to a full second (per request) risks stacking up stalled handlers under load — better to fail fast with `MaxConnectionsError`, return a `503`, and let the client or a load balancer retry elsewhere. Pulse's background job workers (Lesson 05's queue processor) are the opposite case: there's no end-user waiting on a specific response deadline, so a `BlockingConnectionPool` absorbing a brief spike (by making a worker wait a second for a free connection) is strictly better than crashing the worker process over a transient pool-sizing mismatch.
