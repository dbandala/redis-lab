# Solution 07 — Client-Side Caching

**Session A:**
```
127.0.0.1:6379> SET pulse:event:evt2 "Sunset Jazz Night"
OK
127.0.0.1:6379> HELLO 3
... proto 3 ...
127.0.0.1:6379> CLIENT TRACKING on
OK
127.0.0.1:6379> GET pulse:event:evt2
"Sunset Jazz Night"
```

**Session B:**
```
127.0.0.1:6379> SET pulse:event:evt2 "changed by session B"
OK
```

**Step 3:** Back in Session A, Redis delivers an unsolicited push frame on the same connection — no new command needed, though `redis-cli` only actually reads and displays it the next time it touches the socket (pressing Enter, or any subsequent command, is enough to make it appear). On the wire, confirmed directly from the socket, it's exactly:
```
>2
$10
invalidate
*1
$16
pulse:event:evt2
```
Two parts: the literal tag `invalidate`, and an array of the key name(s) that just went stale (`pulse:event:evt2`, matching what Session B wrote).

**Step 4:** No push arrives for `pulse:event:evt3`. Confirmed directly: writing it from Session B produces no message on Session A's connection at all. Default-mode `CLIENT TRACKING` only starts watching a key the moment *this connection* reads it with a command like `GET` — Session A never read `pulse:event:evt3`, so Redis has no reason to think Session A has a stale local copy of it and never notifies about it. (`BCAST` mode exists precisely for the opposite case: watch entire key *prefixes* regardless of whether this connection ever read any specific key under them.)

**Step 5:**
```
127.0.0.1:6379> CLIENT TRACKINGINFO
1) "flags"
2) 1) "on"
3) "redirect"
4) (integer) 0
5) "prefixes"
6) (empty array)
```
`flags` reports `on` (vs. `off` on a connection that never ran `CLIENT TRACKING on`), and `redirect` is `0` — tracking invalidations are delivered on this same connection, not redirected elsewhere.

**Step 6:** Over RESP2, there's no protocol-level channel for the server to push a message outside of a request/reply cycle except Pub/Sub. A RESP2-only client library wanting client-side caching would have to open a **second, dedicated connection subscribed to a special invalidation Pub/Sub channel** (`CLIENT TRACKING on REDIRECT <client-id>` pointed at that subscriber connection is exactly how Redis itself exposes this fallback) rather than receiving invalidations inline on the connection that's actually doing the reads. That's strictly worse operationally: it doubles the connection count per client that wants caching, adds a second thing that can disconnect or fall behind independently of the main connection, and means the invalidation and the data read no longer travel over the same ordered stream — exactly the kind of extra moving part RESP3's native push frames were introduced to eliminate.
