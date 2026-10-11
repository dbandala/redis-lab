# Solution 03 — Caching Patterns: Cache-Aside & Write-Through

**Steps 1–3 — seed, cache-aside, confirm MISS then HIT with a TTL:**

```
$ python3 -c "
import sys; sys.path.insert(0, 'exercises/02-client-libraries-and-connection-pooling')
import redis
from pulse_pool import get_pool
r = redis.Redis(connection_pool=get_pool())

def cache_aside_get_event(event_id):
    cache_key = f'pulse:cache:event:{event_id}'
    cached = r.hgetall(cache_key)
    if cached:
        return cached, 'HIT'
    db_key = f'pulse:db:event:{event_id}'
    data = r.hgetall(db_key)
    if data:
        r.hset(cache_key, mapping=data)
        r.expire(cache_key, 30)
    return data, 'MISS'

r.hset('pulse:db:event:evt1', mapping={'name': 'Night Lights Festival', 'price': '89.00'})
print('first call:', cache_aside_get_event('evt1'))
print('TTL after first call:', r.ttl('pulse:cache:event:evt1'))
print('second call:', cache_aside_get_event('evt1'))
"
first call: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'MISS')
TTL after first call: 30
second call: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'HIT')
```

**Steps 4–5 — write-through updates the cache immediately, TTL untouched:**

```
$ python3 -c "
# ... r defined as above, cache already warm from step 3 ...
def write_through_update_price(event_id, new_price):
    r.hset(f'pulse:db:event:{event_id}', 'price', new_price)
    r.hset(f'pulse:cache:event:{event_id}', 'price', new_price)

write_through_update_price('evt1', '99.00')
print('cache immediately after write-through:', r.hget('pulse:cache:event:evt1', 'price'))
print('TTL unaffected by write-through:', r.ttl('pulse:cache:event:evt1'))
"
cache immediately after write-through: 99.00
TTL unaffected by write-through: 30
```

**Step 6 — the staleness gap cache-aside alone can't close:**

```
$ python3 -c "
# ... r, cache_aside_get_event defined as above ...
r.delete('pulse:db:event:evt1', 'pulse:cache:event:evt1')
r.hset('pulse:db:event:evt1', mapping={'name': 'Night Lights Festival', 'price': '89.00'})
print('repopulate cache:', cache_aside_get_event('evt1'))
r.hset('pulse:db:event:evt1', 'price', '109.00')  # bypass write-through — direct DB write
print('after direct DB update, cache-aside still returns stale:', cache_aside_get_event('evt1'))
"
repopulate cache: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'MISS')
after direct DB update, cache-aside still returns stale: ({'name': 'Night Lights Festival', 'price': '89.00'}, 'HIT')
```

The database genuinely has `price=109.00` at this point, but the cache keeps answering `HIT` with the old `89.00` — proof that cache-aside's correctness depends entirely on *every* writer going through a path that also touches the cache (or on waiting out the TTL). Any writer that updates the database directly (a batch job, an admin tool, a second service) silently reintroduces staleness unless it's also write-through-aware.

**Step 7 — which pattern for which Pulse surface:**

The event listings page (name, venue, date — read constantly, changes rarely) is a clean fit for **cache-aside**: a brief staleness window after a rare edit is unnoticeable, and cache-aside avoids ever writing cache entries for events nobody is actively browsing. The checkout price display needs **write-through**: a price change must be visible to the very next read with zero staleness window, because serving a stale (too-low) price at checkout is a correctness bug, not just a minor UX quirk — exactly the distinction this lesson's comparison table draws between "tolerant of brief staleness" and "correctness-sensitive" data.
