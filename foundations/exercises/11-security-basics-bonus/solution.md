# Solution 11 (Bonus) — Security Basics

```
$ docker exec redis-foundations redis-cli ACL WHOAMI
"default"
$ docker exec redis-foundations redis-cli ACL LIST
1) "user default on nopass sanitize-payload ~* &* +@all"
```
The `default` user has no password (`nopass`), can touch every key (`~*`), every pub/sub channel (`&*`), and every command (`+@all`) — full access, which is why production deployments should never rely on it alone.

```
$ docker exec redis-foundations redis-cli ACL SETUSER student on ">student-pass" "~cache:*" +get +set +ping
OK
$ docker exec redis-foundations redis-cli ACL LIST
1) "user default on nopass sanitize-payload ~* &* +@all"
2) "user student on sanitize-payload #2031f6... ~cache:* resetchannels -@all +get +set +ping"
```
(Quote the `~cache:*` pattern in your shell — an unquoted `~` glob can be expanded by the shell itself before Redis ever sees it.)

```
$ docker exec redis-foundations redis-cli --user student --pass student-pass PING
PONG
$ docker exec redis-foundations redis-cli --user student --pass student-pass SET cache:test "ok"
OK
$ docker exec redis-foundations redis-cli --user student --pass student-pass SET user:9999 "blocked"
(error) NOPERM No permissions to access a key
$ docker exec redis-foundations redis-cli --user student --pass student-pass GET user:1001
(error) NOPERM No permissions to access a key
```
All four match the expectation: allowed commands on allowed keys succeed, anything touching a key outside `cache:*` is rejected.

```
$ docker exec redis-foundations redis-cli --user student --pass student-pass ACL WHOAMI
(error) NOPERM User student has no permissions to run the 'acl|whoami' command
```
It fails — `student`'s rule list only grants `+get +set +ping`; every other command, including `ACL WHOAMI` itself, is denied by default (`-@all` is implicit for a newly created user unless you grant broader categories).

```
$ docker exec redis-foundations redis-cli ACL DELUSER student
(integer) 1
$ docker exec redis-foundations redis-cli ACL LIST
1) "user default on nopass sanitize-payload ~* &* +@all"
```
