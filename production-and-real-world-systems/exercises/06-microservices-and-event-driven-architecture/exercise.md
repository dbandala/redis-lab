# Exercise 06 — Redis in Microservices & Event-Driven Architectures

1. With no subscriber listening, run `PUBLISH pulse:events:test hello` against the lab. Confirm the return value and explain in one sentence what it means for that message.
2. Run the equivalent `XADD pulse:stream:test '*' event hello`, then `XLEN pulse:stream:test`. Confirm the event persisted even though nothing was "subscribed" at the time it was added. Clean up the key afterward.
3. For each of the following three Pulse signals, decide Pub/Sub or Streams, and justify it in one sentence each using the durability/replay criterion from the lesson (not just "Streams is newer"):
   - A "typing / viewing now" presence indicator on an event's page
   - The VIP-claim confirmation notification from Lesson 05's capstone scenario
   - A fraud-detection service that needs to replay the last hour of ticket-purchase events after being redeployed
4. Design (in prose or pseudocode, no need to implement) a cache-invalidation scheme for the scenario where both Pulse's main API and a separate admin tool can write to `pulse:db:event:*`, but only the API currently keeps `pulse:cache:event:*` updated via Lesson 03's write-through function. What message would the admin tool send, and what would subscribing services do on receipt?
5. Classify each of the following as belonging in Redis's "ephemeral tier" (fine if lost) or needing a durable system of record underneath, with one sentence each: a per-user rate-limit counter, a confirmed ticket purchase, a Lesson 04-style distributed lock token, a user's current cart contents mid-checkout.

Compare your work against [solution.md](solution.md) once you're done — not before.
