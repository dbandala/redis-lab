# Exercise 02 — Client Libraries & Connection Pooling

Install the dependency first if you haven't: `pip install "redis==8.1.0"`.

A starter helper, `pulse_pool.py`, is provided in this directory with two functions: `get_pool()` (a standard `ConnectionPool`) and `get_blocking_pool()` (a `BlockingConnectionPool`). Work from the project root (`production-and-real-world-systems/`) so `exercises/02-client-libraries-and-connection-pooling` is importable.

1. Import `get_pool` and open a `redis.Redis(connection_pool=pool)` client. Confirm `r.ping()` returns `True`.
2. Use a pipeline to `SET` five keys (`pulse:test:client:0` … `pulse:test:client:4`) in a single round-trip. Confirm `pipe.execute()` returns a list of 5 `True` values.
3. While that script is still running (add a few seconds of `time.sleep()` at the end if needed), run `docker exec redis-production-and-real-world-systems redis-cli CLIENT LIST | grep pulse-api` from another terminal. Confirm you see a connection with `name=pulse-api` and `lib-name=redis-py` — proof the pool is actually opening *named* connections, not anonymous ones.
4. Using `get_blocking_pool(max_connections=1, timeout=1)`, check out one connection and **do not release it**. Time how long a second `pool.get_connection()` call takes before it raises, and confirm it's approximately the configured `timeout`.
5. Now repeat step 4 with a plain `get_pool(max_connections=1)` instead (check out the sole connection, then try to check out a second one via `pool.get_connection()`). Confirm the failure is immediate (no multi-second wait) — this is the behavioral difference between the two pool types.
6. Write one sentence (as a code comment or in your terminal notes) on which pool type you'd choose for Pulse's HTTP request handlers vs. its background job workers, and why.

Compare your work against [solution.md](solution.md) once you're done — not before.
