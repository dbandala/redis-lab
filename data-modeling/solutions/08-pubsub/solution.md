# Solution 08 — Pub/Sub Messaging

```
$ # terminal A
$ docker exec -it redis-data-modeling redis-cli SUBSCRIBE "events:evt300:updates"
1) "subscribe"
2) "events:evt300:updates"
3) (integer) 1
```

```
$ # terminal B
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt300:updates" "Doors open now"
(integer) 1
```
`PUBLISH` returns `1` — exactly one subscriber received it. Terminal A immediately shows:
```
1) "message"
2) "events:evt300:updates"
3) "Doors open now"
```

```
$ # terminal B
$ docker exec redis-data-modeling redis-cli PUBSUB CHANNELS
1) "events:evt300:updates"
$ docker exec redis-data-modeling redis-cli PUBSUB NUMSUB "events:evt300:updates"
1) "events:evt300:updates"
2) (integer) 1
```
Both match: one active channel, one subscriber on it — consistent with the single terminal-A connection.

```
$ # terminal A: Ctrl+C
$ # terminal B
$ docker exec redis-data-modeling redis-cli PUBSUB CHANNELS
(empty array)
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt300:updates" "Second notice, nobody home"
(integer) 0
```
`PUBLISH` now returns `0` — zero subscribers received the message. The message isn't queued anywhere for terminal A to pick up later if it reconnects; it simply never existed for any client that wasn't actively subscribed at the moment it was published. That's the "no memory" property: a disconnected or slow-to-connect subscriber just misses it, silently.

```
$ # terminal A
$ docker exec -it redis-data-modeling redis-cli PSUBSCRIBE "events:*:updates"
1) "psubscribe"
2) "events:*:updates"
3) (integer) 1
```

```
$ # terminal B
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt300:updates" "First match"
(integer) 1
$ docker exec redis-data-modeling redis-cli PUBLISH "events:evt301:updates" "Second match"
(integer) 1
```
Terminal A receives both, each as a 4-element `pmessage` push instead of the 3-element `message` push from task 2:
```
1) "pmessage"
2) "events:*:updates"
3) "events:evt300:updates"
4) "First match"
1) "pmessage"
2) "events:*:updates"
3) "events:evt301:updates"
4) "Second match"
```
The extra element (position 2) is the **pattern** that matched (`events:*:updates`), inserted before the actual channel the message was published to (position 3). A pattern subscriber needs that extra field because, unlike an exact `SUBSCRIBE`, one subscription can receive messages from many different channels — the push has to tell you both "which subscription caught this" and "which channel it actually came from."
