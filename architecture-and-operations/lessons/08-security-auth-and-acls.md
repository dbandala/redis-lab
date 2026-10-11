# Lesson 08 — Security I: Authentication & ACLs

## Learning Objectives

By the end of this lesson you can:
- Create a least-privilege Redis user restricted to specific commands and a specific key pattern
- Read the exact `NOPERM` errors Redis gives when a user oversteps, and know which clause of the ACL caused each
- Explain why `aclfile` can't be toggled at runtime, and what persisting ACLs to disk actually requires

## Concept

Every lesson so far has connected as the `default` user with no password and full access — fine for a local lab, never acceptable in production. Redis 6+'s ACL system lets you define users scoped to exactly what they need: specific commands, specific key patterns, specific Pub/Sub channels.

```
$ docker exec redis-architecture-and-operations redis-cli ACL WHOAMI
default
$ docker exec redis-architecture-and-operations redis-cli ACL LIST
user default on nopass sanitize-payload ~* &* +@all
```
`default` is wide open: `~*` (any key), `&*` (any channel), `+@all` (every command). Pulse's catalog API shouldn't connect as this user — it should connect as something that can only touch what it actually needs:

```
$ docker exec redis-architecture-and-operations redis-cli ACL SETUSER pulse-api on '>s3cret-api-pass' '~pulse:event:*' '+get' '+set' '+expire' resetchannels
OK
$ docker exec redis-architecture-and-operations redis-cli ACL GETUSER pulse-api
flags
on
sanitize-payload
passwords
f3fceb27085174e7842aac11f3a35cfba378008fb26a64403edb314d049f06c2
commands
-@all +get +set +expire
keys
~pulse:event:*
channels

selectors
```

Reading the clauses: `on` (active), `>s3cret-api-pass` (sets a password — stored only as its SHA-256 hash, never the plaintext), `~pulse:event:*` (can touch *only* keys matching this pattern), `+get +set +expire` (can run *only* these three commands — everything else is implicitly denied, shown as `-@all` first), `resetchannels` (no Pub/Sub access at all).

Connect as this user and the restrictions are real, not advisory:

```
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 SET other:key value
(error) NOPERM No permissions to access a key
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 FLUSHALL
(error) NOPERM User pulse-api has no permissions to run the 'flushall' command
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 KEYS '*'
(error) NOPERM User pulse-api has no permissions to run the 'keys' command
```

Notice the key-pattern violation and the command violation produce **different** error text — worth knowing which is which when you're debugging a confused client in production. And the restriction is total: this user can't even introspect itself unless explicitly granted to:
```
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-api:s3cret-api-pass@localhost:6379 ACL WHOAMI
(error) NOPERM User pulse-api has no permissions to run the 'acl|whoami' command
```

`ACL CAT` lists the command categories ACLs can grant/deny in bulk (`+@read`, `+@write`, `+@dangerous`, etc.) instead of naming commands one by one — useful once you're granting broader roles than this lab's narrow three-command example.

**Persisting ACLs — the part that catches people off guard.** `ACL SETUSER` only changes **in-memory** state. Try to make it durable the way you'd expect:

```
$ docker exec redis-architecture-and-operations redis-cli CONFIG SET aclfile /data/users.acl
(error) ERR CONFIG SET failed (possibly related to argument 'aclfile') - can't set immutable config
```

`aclfile` is an **immutable** config — it can only be set at server **startup** (a command-line flag or in `redis.conf`), never with `CONFIG SET` on a running server. This lab's base container was started without an `aclfile`, so `ACL SETUSER` changes here are gone on the next container restart — exactly the gap `aclfile` exists to close. Demonstrating it for real means starting a **separate** container with the flag from the beginning (note: `redis-server` refuses to start with `--aclfile` pointing at a file that doesn't exist yet, so it has to be created first):

```
$ docker volume create redis-acl-demo-data
$ docker run -d --name redis-acl-demo -v redis-acl-demo-data:/data redis:8.10.1 redis-server --port 6379
$ docker exec redis-acl-demo touch /data/users.acl
$ docker rm -f redis-acl-demo
$ docker run -d --name redis-acl-demo -v redis-acl-demo-data:/data redis:8.10.1 redis-server --port 6379 --aclfile /data/users.acl

$ docker exec redis-acl-demo redis-cli ACL SETUSER pulse-api on '>s3cret-api-pass' '~pulse:event:*' '+get' '+set' '+expire' resetchannels
OK
$ docker exec redis-acl-demo redis-cli ACL SAVE
OK
$ docker exec redis-acl-demo cat /data/users.acl
user default on nopass sanitize-payload ~* &* +@all
user pulse-api on sanitize-payload #f3fceb... ~pulse:event:* resetchannels -@all +get +set +expire

$ docker restart redis-acl-demo
$ docker exec redis-acl-demo redis-cli ACL LIST
user default on nopass sanitize-payload ~* &* +@all
user pulse-api on sanitize-payload #f3fceb... ~pulse:event:* resetchannels -@all +get +set +expire
```

`pulse-api` survived a full process restart because `ACL SAVE` wrote it to `/data/users.acl`, and the server **auto-loads from `aclfile` on startup** whenever one is configured. Without `aclfile` configured at all (this lab's base container), `ACL SETUSER` changes are memory-only, gone the moment the process restarts — a real production deployment needs `aclfile` set from the first boot, not added later as an afterthought.

```
$ docker rm -f redis-acl-demo && docker volume rm redis-acl-demo-data
```

## Official Docs

- [ACL](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/)
- [ACL SETUSER](https://redis.io/docs/latest/commands/acl-setuser/)
- [ACL SAVE](https://redis.io/docs/latest/commands/acl-save/)
- [Authentication](https://redis.io/docs/latest/operate/oss_and_stack/management/security/)

## Exercise

→ [exercises/08-security-auth-and-acls/exercise.md](../exercises/08-security-auth-and-acls/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU330: Redis Security" is dedicated entirely to ACLs, TLS (next lesson), and threat-modeling a multi-tenant Redis deployment.
