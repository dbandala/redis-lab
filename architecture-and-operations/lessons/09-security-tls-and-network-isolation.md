# Lesson 09 — Security II: TLS & Network Isolation

## Learning Objectives

By the end of this lesson you can:
- Generate a self-signed CA and issue a server + client certificate from it
- Run Redis TLS-only (no plaintext port at all) and explain why `tls-auth-clients yes` means a server cert alone isn't enough
- Explain network isolation using nothing but Docker networking as the concrete example, no cloud VPC required

## Concept

ACLs (Lesson 08) control *what* an authenticated connection can do. They say nothing about whether the connection itself can be eavesdropped on or impersonated in transit — that's what TLS is for, and it's a separate concern from authentication on purpose, which is why this lab layers them in two lessons instead of one.

**Generate a throwaway CA, server cert, and client cert:**
```
$ ./scripts/generate-certs.sh
Certs written to .../architecture-and-operations/certs
```
This writes `ca.crt`/`ca.key` (a self-signed Certificate Authority — fine for a lab, never for production, where you'd use a real internal CA or a managed one), `redis.crt`/`redis.key` (the server's cert, signed by that CA, with `subjectAltName` covering `redis-tls` and `localhost`), and `client.crt`/`client.key` (a client cert, signed by the same CA). `certs/` is gitignored — never commit generated key material, even throwaway lab keys.

`compose/tls.yml` starts a Redis node with the plaintext port fully disabled:
```yaml
command: ["redis-server",
  "--port", "0",
  "--tls-port", "6443",
  "--tls-cert-file", "/tls/redis.crt",
  "--tls-key-file", "/tls/redis.key",
  "--tls-ca-cert-file", "/tls/ca.crt",
  "--tls-auth-clients", "yes", ...]
```
`--port 0` means there is no unencrypted way to talk to this node at all — not "TLS preferred," genuinely TLS-only. `--tls-auth-clients yes` additionally requires every *client* to present a cert the server can verify against the same CA — mutual TLS, not just "the server proves who it is."

```
$ docker exec redis-tls redis-cli --tls --cacert /tls/ca.crt -p 6443 PING
Error: Server closed the connection
```
Rejected — no client cert presented, and `tls-auth-clients yes` means the server won't even complete the handshake without one.

```
$ docker exec redis-tls redis-cli --tls --cert /tls/client.crt --key /tls/client.key --cacert /tls/ca.crt -p 6443 PING
PONG
```
Same command, client cert added: the handshake succeeds in both directions — client verifies the server's cert against the CA, server verifies the client's cert against the same CA.

```
$ docker exec redis-tls redis-cli -p 6379 PING
Could not connect to Redis at 127.0.0.1:6379: Connection refused
```
No plaintext fallback exists to accidentally use — `--port 0` removed it, not just discouraged it.

**Network isolation** is the other half of "secure in transit": limiting *who can even attempt a connection* in the first place, independent of whether they'd pass TLS/auth. You don't need a cloud VPC to see this principle — Docker's own per-compose-stack networks demonstrate it directly:

```
$ docker run --rm redis:8.10.1 redis-cli -h redis-tls --tls --cacert /tls/ca.crt PING
Could not connect to Redis at redis-tls:6379: Name or service not known
```
A container not attached to this stack's network can't even *resolve* `redis-tls` — it fails before TLS or auth ever enter the picture, the same way a security group or VPC with no route to a database subnet stops traffic at the network layer, before the database gets a chance to reject bad credentials.

```
$ docker run --rm --network redis-lab-tls_default -v $(pwd)/certs:/tls:ro redis:8.10.1 \
    redis-cli -h redis-tls -p 6443 --tls --cert /tls/client.crt --key /tls/client.key --cacert /tls/ca.crt PING
PONG
```
Same client cert, same command — succeeds purely because this container is attached to `redis-lab-tls_default`, the network Compose created for this stack. In production this is exactly the same principle as a Redis instance living in a private subnet with no public IP and a security group that only admits traffic from your application tier's subnet: unreachable-by-default, with explicit, narrow exceptions — not reachable-by-default with access control bolted on as the only defense.

**Defense in depth, named explicitly:** ACLs (who can do what, once connected), TLS (is the connection itself private and genuine), network isolation (who can even attempt to connect) are three independent layers. Losing one doesn't lose the others — a leaked password is far less damaging if the attacker also needs network-level access and a trusted client cert; a network misconfiguration is far less damaging if every connection still needs a real credential.

## Official Docs

- [TLS](https://redis.io/docs/latest/operate/oss_and_stack/management/security/encryption/)
- [Securing Redis](https://redis.io/docs/latest/operate/oss_and_stack/management/security/)
- [redis-cli --tls options](https://redis.io/docs/latest/manual/cli/#connecting-with-tls)

## Exercise

→ [exercises/09-security-tls-and-network-isolation/exercise.md](../exercises/09-security-tls-and-network-isolation/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU330: Redis Security" covers certificate rotation and mTLS at fleet scale beyond what a single self-signed lab CA can show.
