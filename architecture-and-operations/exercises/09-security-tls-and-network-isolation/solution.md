# Solution 09 — TLS & Network Isolation

**Step 1:** `ca.crt`, `redis.crt`, `client.crt` are certificates — public, shareable, meant to be presented. `ca.key`, `redis.key`, `client.key` are private keys — never shared, never committed (hence `certs/` being gitignored). `ca.crt`/`ca.key` are the one pair shared across both issuances: `redis.crt` and `client.crt` were each signed using `ca.key`, which is exactly what lets both sides trust each other by trusting the same CA.

```
$ docker exec redis-tls redis-cli -p 6443 PING
Error: Connection reset by peer
```
Speaking plaintext RESP to a TLS-only socket isn't "refused" (the port is open and listening) — the server sees bytes it can't parse as a valid TLS handshake and drops the connection, a different failure mode than a closed port.

```
$ docker exec redis-tls redis-cli --tls -p 6443 PING
Could not connect to Redis at 127.0.0.1:6443: SSL_connect failed: certificate verify failed
```
Without `--cacert`, `redis-cli` has no CA to check the server's certificate against — it can't confirm `redis.crt` is signed by anyone it trusts, so it refuses to proceed rather than connect to an unverified endpoint.

```
$ docker exec redis-tls redis-cli --tls --cacert /tls/ca.crt -p 6443 PING
Error: Server closed the connection
```
This one is specifically `--tls-auth-clients yes` on the server — the server completed its half (proved its own identity via `redis.crt`) but then required the *client* to present a certificate too, got none, and closed the connection. This is a different, more specific failure than generic "TLS didn't negotiate."

```
$ docker exec redis-tls redis-cli --tls --cert /tls/client.crt --key /tls/client.key --cacert /tls/ca.crt -p 6443 PING
PONG
```

**Step 6:**
```
$ docker run --rm redis:8.10.1 redis-cli -h redis-tls -p 6443 PING
Could not connect to Redis at redis-tls:6443: Name or service not known
$ docker run --rm --network redis-lab-tls_default -v $(pwd)/certs:/tls:ro redis:8.10.1 \
    redis-cli -h redis-tls -p 6443 --tls --cert /tls/client.crt --key /tls/client.key --cacert /tls/ca.crt PING
PONG
```
The first container can't even resolve `redis-tls` — it was never attached to `redis-lab-tls_default`, so from its point of view the hostname simply doesn't exist, let alone a reachable port. The second, attached to that network, resolves it immediately and completes the same full mutual-TLS handshake as step 5.

**Step 7:** TLS negotiation happens **strictly before** anything ACL-related — the TLS handshake (certificate exchange, encryption setup) completes at the transport layer before a single RESP command, including `AUTH` or an ACL-bound connection's first command, is ever sent or readable by either side. This ordering means TLS and ACLs fail closed independently of each other: without TLS, credentials and all traffic travel in the clear over the network (anyone who can observe the wire sees the password and every command/response), even if the ACL itself is perfectly scoped — that's the bigger practical gap, because a leaked password observed in transit defeats a well-designed ACL instantly. Without ACLs but with TLS, the connection is private and the two ends are verified, but whoever holds a valid credential (or, with no `requirepass`/ACL at all, *anyone* who can reach the port) still gets unrestricted access once connected — a real gap, but one that at least requires network-level reachability first, which is why this course treats network isolation, TLS, and ACLs as three independent layers rather than any one of them being "enough" on its own.
