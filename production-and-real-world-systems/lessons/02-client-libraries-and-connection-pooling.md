# Lesson 02 — Client Libraries & Connection Pooling

## Learning Objectives

By the end of this lesson you can:
- Explain why opening a new TCP connection per request is too slow for production Redis traffic, and how a connection pool fixes that
- Configure `redis-py`'s `ConnectionPool` and `BlockingConnectionPool`, and choose correctly between them
- Configure retry-with-backoff (`Retry` + `ExponentialBackoff`) so transient network blips don't become application errors
- Use pipelining to batch round-trips, and `decode_responses` to stop juggling bytes in application code
- Read a `redis-py` snippet and recognize the equivalent concept in `ioredis` (Node.js) and Lettuce/Jedis (Java) from a comparison table, without needing to run either

## Concept

Every lesson before this one talked to Redis through `redis-cli` — one process, one connection, opened and closed around a single command. A real Pulse API server is the opposite: dozens of concurrent request handlers, all needing to talk to Redis *at the same time*, for the lifetime of the process. Opening a fresh TCP connection (and, if TLS is on, a fresh handshake) per request is the single most common cause of needless Redis latency in production systems — the fix is a **connection pool**: a small set of long-lived connections, checked out by a handler, used, and returned.

This is the course's first Python dependency. Install `redis-py`, the official client:

```
$ pip install "redis==8.1.0"
```

(A virtualenv is recommended — see this module's README — but any Python 3 with that package importable works.)

### `ConnectionPool` — the default choice

```python
import redis
from redis.retry import Retry
from redis.backoff import ExponentialBackoff

pool = redis.ConnectionPool(
    host="localhost", port=6379, decode_responses=True,
    max_connections=10,
    retry=Retry(ExponentialBackoff(cap=1.0, base=0.01), retries=3),
    retry_on_error=[redis.exceptions.ConnectionError, redis.exceptions.TimeoutError],
    health_check_interval=30,
    client_name="pulse-api",
)
r = redis.Redis(connection_pool=pool)
```

A `ConnectionPool` doesn't open `max_connections` sockets up front — connections are created **lazily**, on first use, and reused afterward. `max_connections` is a ceiling, not a pre-allocation. Every `redis.Redis(connection_pool=pool)` instance sharing the same `pool` object shares that ceiling, which is the point: construct one pool per process (e.g. a module-level singleton, as in this lesson's `pulse_pool.py`), not one per request.

`decode_responses=True` means every reply comes back as `str`, not `bytes` — almost always what you want in application code; leave it `False` only if you're storing genuinely binary payloads (like the RAG lesson's packed vector bytes in Level 3).

`retry` + `retry_on_error` is what actually makes a pool production-grade: without it, a single dropped TCP connection (a brief network blip, a Redis restart) surfaces as a raw `ConnectionError` in your request handler. With `ExponentialBackoff(cap=1.0, base=0.01)` and `retries=3`, redis-py retries the same command after `~8ms`, then `~16ms`, then `~32ms` (capped at `1.0s`) before giving up — transparent to the caller unless the outage genuinely outlasts all three attempts.

Confirm pooling and pipelining actually work against the lab:

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
"
PING: True
pipeline results: [True, True, True, True, True]
```

A `pipeline()` batches all 5 `SET`s into **one** round-trip instead of 5 — the client buffers the commands, sends them in a single TCP write, and reads all 5 replies off the wire at once. For a handler issuing several independent commands, pipelining is usually a bigger win than anything you can do by tuning pool size.

Confirm the pool's connections are genuinely named and reused with `CLIENT LIST`:

```
$ docker exec redis-production-and-real-world-systems redis-cli CLIENT LIST | grep pulse-api
id=21 addr=192.168.65.1:26978 laddr=172.20.0.2:6379 fd=23 name=pulse-api age=1 idle=1 flags=N db=0 ... lib-name=redis-py lib-ver=8.1.0 ...
```

### `BlockingConnectionPool` — when backpressure beats failure

A plain `ConnectionPool` raises `ConnectionError: No connection available.` the instant all `max_connections` are checked out and a new request comes in. For a background worker pool (Lesson 05's job queue, the capstone's notification processor), that's often the wrong failure mode — you'd rather a caller *wait* briefly for a connection to free up than fail outright. `BlockingConnectionPool` does exactly that, up to a `timeout`:

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
    print(f'blocked for {time.time()-t0:.2f}s then raised: {type(e).__name__}')
"
blocked for 1.00s then raised: ConnectionError
```

With only 1 connection checked out and never released, the second caller blocks for the full `timeout` (1s here) before giving up — exactly the same exception type as the non-blocking pool, just delayed. Choose `BlockingConnectionPool` for worker/queue code where a short wait is acceptable; choose plain `ConnectionPool` for request-path code where you'd rather fail fast and let the caller retry at a higher level (e.g. an HTTP 503 with `Retry-After`).

### The same shape in other languages

You will not run these — they're here so a `redis-py` config maps onto what you'd see in a Node.js or Java Pulse service:

```javascript
// ioredis (Node.js) — a single Redis instance already pools internally;
// most apps just need one shared client, not a manual pool.
const Redis = require("ioredis");
const redis = new Redis({
  host: "localhost", port: 6379,
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => Math.min(times * 50, 2000), // custom backoff
  enableAutoPipelining: true, // batches commands issued in the same tick automatically
});
```

```java
// Lettuce — ONE StatefulRedisConnection is thread-safe and multiplexes every
// command over a single Netty connection. You do NOT pool Lettuce connections
// for ordinary commands; you share the one connection across threads.
RedisClient client = RedisClient.create("redis://localhost:6379");
StatefulRedisConnection<String, String> connection = client.connect();
RedisCommands<String, String> sync = connection.sync();
// A pool (Commons Pool 2) is only needed for commands that can't safely
// share a multiplexed connection — e.g. blocking BRPOP, or MULTI/EXEC.

// Jedis — historically pool-based (JedisPool), because each Jedis instance
// holds ONE blocking socket, unlike Lettuce's multiplexing.
//   LEGACY (still widely deployed, but deprecated since Jedis 7.2):
JedisPool pool = new JedisPool("localhost", 6379);
try (Jedis jedis = pool.getResource()) {
    jedis.set("pulse:event:evt1", "Night Lights Festival");
}
//   CURRENT (Jedis 8.0+): JedisPooled was deleted; Jedis's new client classes
//   (RedisClient / RedisClusterClient / RedisSentinelClient) manage pooling
//   internally, the same philosophy ioredis and ConnectionPool already use.
```

| Client | Pooling model | Backpressure on exhaustion |
|---|---|---|
| `redis-py` `ConnectionPool` | Discrete pooled connections, checked out per command | Raises `MaxConnectionsError` (a `ConnectionError` subclass) immediately |
| `redis-py` `BlockingConnectionPool` | Same, but callers wait | Blocks up to `timeout`, then raises |
| `ioredis` | One client multiplexes commands itself; no manual pool needed for most apps | Queues internally, retries per `retryStrategy` |
| Lettuce | One `StatefulRedisConnection` multiplexes over Netty; pool only for non-multiplexing commands | N/A for ordinary commands |
| Jedis (legacy `JedisPool`) | Discrete pooled sockets, one blocking socket per `Jedis` instance | `getResource()` blocks/throws per pool config |

The common thread across all four: **never construct a new client (or connection) per request.** Build one pool (or one shared multiplexed client) at process startup and reuse it for the process's lifetime — the exact mistake this lesson's exercise asks you to detect and fix.

## Official Docs

- [redis-py: Connecting to the server](https://redis.io/docs/latest/develop/clients/redis-py/connect/)
- [redis-py: Pipelines and transactions](https://redis.io/docs/latest/develop/clients/redis-py/transpipe/)
- [Redis clients: pools and multiplexing](https://redis.io/docs/latest/develop/clients/pools-and-muxing/)
- [ioredis: Connect](https://redis.io/docs/latest/develop/clients/nodejs/)
- [Lettuce: Connect](https://redis.io/docs/latest/develop/clients/lettuce/connect/)
- [Jedis: Connect](https://redis.io/docs/latest/develop/clients/jedis/connect/)

## Exercise

→ [exercises/02-client-libraries-and-connection-pooling/exercise.md](../exercises/02-client-libraries-and-connection-pooling/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU101: Introduction to Redis Data Structures" covers client basics; most client-library depth comes directly from each client's own docs linked above rather than a dedicated RU course.
