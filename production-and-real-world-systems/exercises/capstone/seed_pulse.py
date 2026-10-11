"""Seeds Pulse's VIP-claim capstone scenario against compose/observability.yml.

Run from the exercises/capstone/ directory: `python3 seed_pulse.py`
"""
import redis

REDIS_HOST = "localhost"
REDIS_PORT = 6410  # compose/observability.yml maps redis-observability to host 6410

EVENT_ID = "vip1"

CLEANUP_PATTERNS = [
    "pulse:cache:event:vip1",
    "pulse:db:event:vip1",
    "pulse:db:claim:vip1",
    "pulse:lock:vip-claim:vip1",
    "pulse:fencing:event:vip1",
    "pulse:ratelimit:vip-claim:*",
    "pulse:queue:notifications:*",
    "pulse:notified:*",
]


def get_pool(max_connections=10):
    return redis.ConnectionPool(
        host=REDIS_HOST, port=REDIS_PORT, decode_responses=True, max_connections=max_connections
    )


def seed():
    r = redis.Redis(connection_pool=get_pool())
    for pattern in CLEANUP_PATTERNS:
        keys = r.keys(pattern)
        if keys:
            r.delete(*keys)
    r.hset(
        f"pulse:db:event:{EVENT_ID}",
        mapping={"name": "Night Lights Festival", "price": "89.00", "vip_slots_remaining": "1"},
    )
    print(f"seeded pulse:db:event:{EVENT_ID} with 1 VIP slot remaining")


if __name__ == "__main__":
    seed()
