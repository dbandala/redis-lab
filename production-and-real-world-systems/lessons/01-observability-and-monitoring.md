# Lesson 01 — Observability & Monitoring

## Learning Objectives

By the end of this lesson you can:
- Read the sections of `INFO` that actually matter operationally (`server`, `stats`, `memory`, `clients`)
- Capture and read the slow log (`SLOWLOG`) to find individual commands that ran slower than a threshold
- Capture and read latency spikes by event class (`LATENCY HISTORY`/`LATEST`) rather than by individual command
- Explain what `redis_exporter` translates `INFO`'s text fields into, and read the resulting metrics in Prometheus and a pre-built Grafana dashboard

## Concept

Every prior lesson (and every prior level) checked Redis's behavior by reading command output — did `GET` return the right value, did `CLUSTER INFO` say `cluster_state:ok`. Production operations needs a different question answered continuously, not on demand: **is Redis healthy right now, and was it healthy five minutes ago when something went wrong?** That's what this lesson's stack — `compose/observability.yml` — is for. Bring it up instead of the base stack:

```
$ docker compose -f compose/observability.yml up -d
```

### `INFO` — the single command that answers "is Redis OK"

```
$ docker exec redis-observability redis-cli INFO server | head -6
redis_version:8.10.1
redis_git_sha1:00000000
redis_git_dirty:1
redis_build_id:d10c6de5a4972fa0
redis_mode:standalone
os:Linux 6.10.14-linuxkit aarch64
```

```
$ docker exec redis-observability redis-cli INFO stats | head -6
total_connections_received:11
total_commands_processed:32
instantaneous_ops_per_sec:5
total_net_input_bytes:870
total_net_output_bytes:42208
total_net_repl_input_bytes:0
```

`INFO` is organized into sections (`server`, `clients`, `memory`, `persistence`, `stats`, `replication`, `cpu`, `commandstats`, `keyspace`, and more); `INFO <section>` narrows to just one. For day-to-day health, `stats` (`instantaneous_ops_per_sec`, `rejected_connections`, `expired_keys`, `evicted_keys`) and `memory` (`used_memory`, `maxmemory`, `mem_fragmentation_ratio` — all covered mechanically back in Level 4, Lesson 06) are what you actually watch; `server` is mostly useful for confirming version/build during an incident.

### `SLOWLOG` — which individual commands were slow

By default, Redis only logs commands slower than `slowlog-log-slower-than` microseconds (10000 = 10ms). Lower it to log everything, generate some traffic, and read the log:

```
$ docker exec redis-observability redis-cli CONFIG SET slowlog-log-slower-than 0
OK
$ docker exec redis-observability redis-cli SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-observability redis-cli GET pulse:event:evt1
"Night Lights Festival"
$ docker exec redis-observability redis-cli SLOWLOG LEN
(integer) 4
$ docker exec redis-observability redis-cli SLOWLOG GET 3
1) 1) (integer) 4
   2) (integer) 1791686374
   3) (integer) 1
   4) 1) "SLOWLOG"
      2) "LEN"
   5) "127.0.0.1:38744"
   6) ""
2) 1) (integer) 3
   2) (integer) 1791686374
   3) (integer) 3
   4) 1) "GET"
      2) "pulse:event:evt1"
   5) "127.0.0.1:38732"
   6) ""
3) 1) (integer) 2
   2) (integer) 1791686374
   3) (integer) 77
   4) 1) "SET"
      2) "pulse:event:evt1"
      3) "Night Lights Festival"
   5) "127.0.0.1:38730"
   6) ""
```

Each entry is `[id, unix_timestamp, duration_microseconds, command_and_args, client_addr, client_name]`. **With the threshold at `0`, every command gets logged, including `SLOWLOG LEN` and `SLOWLOG GET` themselves** — fine for this demo, never leave it at `0` in production (the slow log itself becomes overhead, and it fills with noise). Reset it afterward:

```
$ docker exec redis-observability redis-cli CONFIG SET slowlog-log-slower-than 10000
OK
$ docker exec redis-observability redis-cli SLOWLOG RESET
OK
```

### `LATENCY` — spikes by event class, not by command

`SLOWLOG` tells you *which command* was slow. `LATENCY` tells you *what kind of internal event* caused a spike — useful when the slow thing isn't a single command at all (a fork for `BGSAVE`, an expire cycle, a slow fsync). Enable it and manufacture a real spike with `DEBUG SLEEP` (this lab's compose enables `--enable-debug-command yes` specifically so this works — it's disabled by default, intentionally, since blocking the whole event loop on command is not something you want reachable in production):

```
$ docker exec redis-observability redis-cli CONFIG SET latency-monitor-threshold 100
OK
$ docker exec redis-observability redis-cli DEBUG SLEEP 0.2
OK
$ docker exec redis-observability redis-cli LATENCY HISTORY command
1) 1) (integer) 1791686366
   2) (integer) 201
$ docker exec redis-observability redis-cli LATENCY LATEST
1) 1) "command"
   2) (integer) 1791686366
   3) (integer) 201
   4) (integer) 201
```

`DEBUG SLEEP 0.2` blocked the single-threaded event loop for 200ms, and `LATENCY` recorded it under the `command` event class at `201ms` (the extra 1ms is real overhead, not an artifact) — because `latency-monitor-threshold` was set to `100`ms, anything crossing that bar gets captured. `LATENCY LATEST`'s four columns are `[event-name, last-occurrence-timestamp, latest-duration-ms, max-duration-ms-ever-seen]`.

### `redis_exporter` → Prometheus → Grafana: the same numbers, continuously

Reading `INFO`/`SLOWLOG`/`LATENCY` by hand works for "what's happening right now" — it doesn't answer "what did this metric look like 20 minutes ago," because nothing is retaining the history. `oliver006/redis_exporter` closes that gap: it polls `INFO` (among other things) on an interval and re-exposes the fields as Prometheus metrics:

```
$ curl -s localhost:9121/metrics | grep -E "^redis_(up|connected_clients|commands_processed_total) "
redis_up 1
redis_connected_clients 1
redis_commands_processed_total 32
```

`redis_up` is the exporter's own synthetic health check (`1` if it could reach and `PING` the target Redis, `0` if not) — the single most important metric to alert on, since every other metric from this exporter is meaningless if this one is `0`. `total_commands_processed` from `INFO stats` became `redis_commands_processed_total` — a consistent naming convention (Prometheus-style `snake_case` with a unit/type suffix) across every field the exporter re-exposes.

Prometheus scrapes that `/metrics` endpoint every 5 seconds (this lab's `observability/prometheus/prometheus.yml`) and retains the history; Grafana (pre-provisioned — no setup needed) queries Prometheus and renders it. Open **http://localhost:3000** (no login required — anonymous viewer access is enabled for this lab) and you'll see the **Pulse Redis — Level 5 Observability** dashboard with 7 panels, each tied to something this course already taught:

| Panel | What it reads | Lesson it pays off |
|---|---|---|
| Redis Up | `redis_up` | This lesson — the one metric to alert on |
| Connected Clients | `redis_connected_clients` | Lesson 02's connection pools |
| Memory Used | `redis_memory_used_bytes` | Level 4, Lesson 06 (eviction/memory) |
| Redis Version / Uptime | `redis_uptime_in_seconds` | — |
| Commands/sec | `rate(redis_commands_processed_total[1m])` | This lesson's `SLOWLOG`, and the capstone's traffic check |
| Cache Hits vs Misses/sec | `redis_keyspace_hits_total` / `_misses_total` | Lesson 03's cache-aside |
| Slow Commands/sec | `redis_slowlog_commands_total` | This lesson's `SLOWLOG` section |

Generate some real traffic and watch the "Commands/sec" panel move:

```
$ docker exec redis-observability redis-benchmark -h localhost -p 6379 -n 20000 -q
```

Confirmed live during this module's build: a `rate(redis_commands_processed_total[1m])` query jumped from effectively idle to **7364 commands/sec** within seconds of running that benchmark — the dashboard isn't decorative, it reflects exactly what the instance is doing.

## Official Docs

- [INFO](https://redis.io/docs/latest/commands/info/)
- [SLOWLOG](https://redis.io/docs/latest/commands/slowlog/)
- [LATENCY HISTORY](https://redis.io/docs/latest/commands/latency-history/)
- [redis_exporter (the Prometheus exporter this lesson uses)](https://github.com/oliver006/redis_exporter)

## Exercise

→ [exercises/01-observability-and-monitoring/exercise.md](../exercises/01-observability-and-monitoring/exercise.md)

## Further Reading

[Redis University](https://university.redis.io) — "RU202: Redis Persistence and Replication" touches on `INFO`-based health checks; the `redis_exporter` project's own README documents every metric this lesson's dashboard draws from.
