# Solution 06 — Redis in Microservices & Event-Driven Architectures

**Steps 1–2 — Pub/Sub drops, Streams persists:**

```
$ docker exec redis-production-and-real-world-systems redis-cli PUBLISH pulse:events:test hello
(integer) 0
$ docker exec redis-production-and-real-world-systems redis-cli XADD pulse:stream:test '*' event hello
"1791686126017-0"
$ docker exec redis-production-and-real-world-systems redis-cli XLEN pulse:stream:test
(integer) 1
$ docker exec redis-production-and-real-world-systems redis-cli DEL pulse:stream:test
(integer) 1
```

`PUBLISH` returned `0` — zero subscribers received it, and that message is now unrecoverable; there's no log it lives in. The `XADD` succeeded and `XLEN` confirms the event is sitting in the stream whether or not anything was reading at the time — a consumer group created after the fact could still `XREADGROUP` from the beginning and see it.

**Step 3 — Pub/Sub or Streams per signal:**

- **Presence indicator ("3 people viewing"):** Pub/Sub. A missed update is immediately superseded by the next one a few seconds later — durability would only add overhead to a signal that's self-correcting by nature.
- **VIP-claim confirmation notification:** Streams (or Lesson 05's reliable list-queue). Losing this silently means a customer never gets their confirmation email — an unacceptable, support-ticket-generating failure, not a self-correcting one.
- **Fraud-detection replay after redeploy:** Streams. The whole requirement is "catch up on everything since downtime began," which is exactly what a consumer group's tracked delivery position gives you and Pub/Sub categorically cannot.

**Step 4 — cache-invalidation scheme for a second writer:**

The admin tool, after updating `pulse:db:event:evt1` directly, publishes an invalidation event — e.g. `PUBLISH pulse:invalidate:event evt1` (Pub/Sub is the right choice here specifically, by the same criterion as step 3: an invalidation message that's missed is self-correcting, since the cache entry will still expire on its own TTL eventually; the goal is just to shorten that window, not guarantee it). Every service instance that maintains a local read-path against `pulse:cache:event:*` subscribes to `pulse:invalidate:event` and, on receipt of an event ID, deletes (or re-fetches) that key's cache entry — converting "every writer must remember to call `write_through_update_price`" into the smaller obligation "every writer must remember to announce what it changed," which is far easier to enforce consistently across teams that don't share a codebase (the API service and a separately-maintained admin tool).

**Step 5 — ephemeral tier vs. durable system of record:**

- **Per-user rate-limit counter:** Ephemeral tier. Losing it just resets the window early — a minor availability blip, not data loss.
- **Confirmed ticket purchase:** Needs a durable system of record. This is money and inventory; Redis may cache a view of it, but something else must be the record it's recoverable from.
- **Lesson 04-style distributed lock token:** Ephemeral tier. A lock is a coordination mechanism for the duration of an operation, not data anyone needs to recover after the fact — once released or expired, its job is done.
- **User's cart contents mid-checkout:** Needs a durable system of record (or at minimum, durable persistence) if losing it mid-purchase would mean a customer loses their in-progress order — which checkout flows generally cannot tolerate, unlike a casually-abandoned shopping cart from browsing.
