# Solution 08 — Authentication & ACLs

```
$ docker exec redis-architecture-and-operations redis-cli SET pulse:event:evt5 "Harbor Comedy Hour"
OK
```

```
$ docker exec redis-architecture-and-operations redis-cli ACL SETUSER pulse-reports on '>r3port-pass' '~pulse:event:*' '+get' '+mget' resetchannels
OK
$ docker exec redis-architecture-and-operations redis-cli ACL GETUSER pulse-reports
flags
on
sanitize-payload
passwords
7dc151a91814ca1b21a09bf506750d0dc2f5e2b776d336ee135caa441ce5c24d
commands
-@all +get +mget
keys
~pulse:event:*
channels

selectors
```
`-@all +get +mget` — everything denied by default, then exactly two commands re-granted; `~pulse:event:*` scopes every one of them to that key pattern; the empty `channels` line (from `resetchannels`) means no Pub/Sub access at all.

```
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-reports:r3port-pass@localhost:6379 GET pulse:event:evt5
"Harbor Comedy Hour"
```

```
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-reports:r3port-pass@localhost:6379 SET pulse:event:evt5 "overwritten"
(error) NOPERM User pulse-reports has no permissions to run the 'set' command
```
Rejected at the **command** level — `set` was never granted at all, regardless of which key it targets.

```
$ docker exec redis-architecture-and-operations redis-cli -u redis://pulse-reports:r3port-pass@localhost:6379 GET pulse:session:tok1
(error) NOPERM No permissions to access a key
```
Rejected at the **key-pattern** level instead — `get` itself is allowed, but `pulse:session:tok1` doesn't match `~pulse:event:*`, so Redis doesn't even say which command you ran; this error is key-pattern-specific and command-agnostic by design.

```
$ docker exec redis-architecture-and-operations redis-cli ACL CAT
...
read
...
```
The `read` category. `+@read` would have granted `GET`, `MGET`, `EXISTS`, `TTL`, and every other command tagged as a read in one clause, instead of listing `+get +mget` by hand — the right move once a role needs more than a couple of specific commands, at the cost of being less precisely scoped than naming exactly two commands.

**Step 7:** The minimal change would be `ACL SETUSER pulse-reports resetchannels &pulse:updates:* +subscribe +psubscribe` — add back channel access scoped to only the specific channel pattern the dashboard needs, plus the two Pub/Sub commands required to use it. `resetchannels` is a sensible default despite the extra step later because it makes "no channel access" the thing you have to opt out of being safe from, not the thing you have to remember to lock down — the same reasoning as `-@all` being the implicit starting point for commands. A new user that can't yet do anything is always a safer failure mode than one that silently inherited broad access you forgot to restrict.
