# Exercise 08 — Pub/Sub Messaging

You'll need **two terminals** for this exercise — Pub/Sub subscribers block, so they need their own terminal separate from the one publishing.

1. In terminal A: `docker exec -it redis-data-modeling redis-cli SUBSCRIBE "events:evt300:updates"`. Leave it running.
2. In terminal B: publish the message `"Doors open now"` to `events:evt300:updates`. What does `PUBLISH` return, and what shows up in terminal A?
3. In terminal B: run `PUBSUB CHANNELS` and `PUBSUB NUMSUB "events:evt300:updates"`. Do the numbers match what you'd expect with exactly one subscriber?
4. Stop the subscriber in terminal A (Ctrl+C). In terminal B, publish another message to the same channel. What does `PUBLISH` return this time, and what does that number tell you about what happened to the message?
5. In terminal A, subscribe with a pattern instead: `PSUBSCRIBE "events:*:updates"`. In terminal B, publish to two different channels that match the pattern (e.g. `events:evt300:updates` and `events:evt301:updates`). How does the pattern-matched push you see in terminal A differ from the exact-channel push you saw in task 2?

Check your answers against [solutions/08-pubsub/solution.md](../../solutions/08-pubsub/solution.md).
