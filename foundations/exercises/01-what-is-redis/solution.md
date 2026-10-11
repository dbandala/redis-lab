# Solution 01 — What Is Redis?

1. Because Redis serves reads/writes straight out of RAM, whereas a disk-backed relational database typically has to hit disk (or a disk-page cache) and walk index structures on-disk — RAM access is orders of magnitude faster than disk I/O.
2. **True.** Redis executes one command at a time on a single main thread (an event loop handles many connections, but never runs two commands concurrently). Since `INCR` runs to completion before the next command starts, there's no window where two clients can interleave and lose an update — no client-side locking required.
3. RSALv2, SSPLv1, or AGPLv3 — a distributor picks one. **AGPLv3** is the OSI-approved open-source option (the other two are "source available" but not OSI open source).
4. Valkey is a BSD-3-Clause-licensed fork of Redis, created in March 2024 (forked from the last BSD release, 7.2.4) by former Redis maintainers together with AWS, Google Cloud, Oracle, and others, now governed by the Linux Foundation. It exists because Redis Ltd. moved Redis itself off the permissive BSD license in 2024; Valkey preserves a permanently BSD-licensed, wire-compatible alternative. AWS ElastiCache/MemoryDB default to it today.
5. Command and real output from this lab:
   ```
   $ docker exec redis-foundations redis-cli INFO server | grep redis_version
   redis_version:8.10.1
   ```
