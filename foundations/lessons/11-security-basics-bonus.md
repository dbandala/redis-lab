# Lesson 11 (Bonus) — Security Basics

> This lesson isn't one of the five core Foundations topics — it's included because "how do I stop any connected client from doing anything to any key" is a question every beginner asks eventually, and it's a small enough topic to cover now. Deeper security (TLS, network isolation, secrets management) comes back in Level 4.

## Learning Objectives

By the end of this lesson you can:
- Explain the difference between `requirepass` and ACLs
- Create a scoped ACL user limited to specific commands and key patterns
- Recognize a `NOPERM` error and know what it's telling you

## Concept

**`requirepass`** (set in `redis.conf` or via `CONFIG SET requirepass <password>`) is the original, simplest form of Redis auth: one shared password, and any client that supplies it gets full access to everything. It's still valid and still shows up in older deployments, but it's all-or-nothing.

**ACLs** (Access Control Lists, since Redis 6) replace that with per-user accounts, each restricted to exactly the commands and key patterns they need:

```
ACL SETUSER student on ">student-pass" ~cache:* +get +set +ping
```
Reading this rule left to right: `student` — the username; `on` — enabled; `>student-pass` — set this password (a `>` prefix means "here's a plaintext password, hash it for storage"); `~cache:*` — this user may only touch keys matching the pattern `cache:*`; `+get +set +ping` — this user may only run `GET`, `SET`, and `PING` (everything else is denied by default for a newly created user).

Once a client authenticates as a restricted user, any command or key outside its allow-list fails with a `NOPERM` error — not a crash, not silent data loss, just a clear rejection you can log and alert on.

**Why this matters even at Foundations level:** a real application almost never needs a single shared full-access credential. An API service that only ever reads/writes `session:*` and `cache:*` keys should authenticate as a user that can *only* touch `session:*` and `cache:*` — so a bug or a leaked credential in that one service can't be used to read or wipe unrelated data.

**Try it:**
```
$ docker exec redis-foundations redis-cli ACL SETUSER student on ">student-pass" "~cache:*" +get +set +ping
OK
$ docker exec redis-foundations redis-cli --user student --pass student-pass SET cache:test "ok"
OK
$ docker exec redis-foundations redis-cli --user student --pass student-pass SET user:9999 "blocked"
NOPERM No permissions to access a key
```

## Official Docs

- [AUTH](https://redis.io/docs/latest/commands/auth/)
- [ACL SETUSER](https://redis.io/docs/latest/commands/acl-setuser/)
- [Redis security overview](https://redis.io/docs/latest/operate/oss_and_stack/management/security/)

## Exercise

→ [exercises/11-security-basics-bonus/exercise.md](../exercises/11-security-basics-bonus/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) covers ACLs, TLS, and hardening in more depth in its operations-track courses — also previewed in Level 4 of this course.
