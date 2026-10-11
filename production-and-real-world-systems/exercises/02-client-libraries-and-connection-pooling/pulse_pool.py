"""Shared connection-pool helper for Pulse's Python services (Level 5, Lesson 02)."""
import redis
from redis.backoff import ExponentialBackoff
from redis.retry import Retry

REDIS_HOST = "localhost"
REDIS_PORT = 6379


def get_pool(max_connections=10):
    """A standard pool: connections are created lazily and reused, capped at max_connections."""
    return redis.ConnectionPool(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
        max_connections=max_connections,
        retry=Retry(ExponentialBackoff(cap=1.0, base=0.01), retries=3),
        retry_on_error=[redis.exceptions.ConnectionError, redis.exceptions.TimeoutError],
        health_check_interval=30,
        client_name="pulse-api",
    )


def get_blocking_pool(max_connections=10, timeout=5):
    """Like get_pool, but callers BLOCK (up to `timeout` seconds) instead of raising
    ConnectionError when all max_connections are checked out — use this for a worker
    pool where backpressure is preferable to a hard failure."""
    return redis.BlockingConnectionPool(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
        max_connections=max_connections,
        timeout=timeout,
        client_name="pulse-worker",
    )
