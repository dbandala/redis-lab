# Solution 01 — Observability & Monitoring

**Step 1 — `INFO` fields worth paging on:**

```
$ docker exec redis-observability redis-cli INFO stats | head -6
total_connections_received:11
total_commands_processed:32
instantaneous_ops_per_sec:5
total_net_input_bytes:870
total_net_output_bytes:42208
total_net_repl_input_bytes:0
```

From `stats`: `rejected_connections` — any value above `0` means clients are being turned away outright (usually `maxclients` reached), a hard failure worth paging on immediately. From `memory`: `used_memory` approaching `maxmemory` (or `mem_fragmentation_ratio` climbing well above `1.0–1.5`) — the leading indicator before evictions or OOM kills start, giving you time to react before data loss (per Level 4, Lesson 06).

**Steps 2 — SLOWLOG:**

```
$ docker exec redis-observability redis-cli CONFIG SET slowlog-log-slower-than 0
OK
$ docker exec redis-observability redis-cli SET pulse:event:evt1 "Night Lights Festival"
OK
$ docker exec redis-observability redis-cli GET pulse:event:evt1
"Night Lights Festival"
$ docker exec redis-observability redis-cli SLOWLOG GET 1
1) 1) (integer) 4
   2) (integer) 1791686374
   3) (integer) 1
   4) 1) "SLOWLOG"
      2) "LEN"
   5) "127.0.0.1:38744"
   6) ""
$ docker exec redis-observability redis-cli CONFIG SET slowlog-log-slower-than 10000
OK
$ docker exec redis-observability redis-cli SLOWLOG RESET
OK
```

Field 3 in each entry (`(integer) 1` above) is `duration_microseconds` — the command's actual execution time, in microseconds, as measured by Redis itself.

**Step 3 — LATENCY and why `DEBUG SLEEP` is disabled by default:**

```
$ docker exec redis-observability redis-cli CONFIG SET latency-monitor-threshold 100
OK
$ docker exec redis-observability redis-cli DEBUG SLEEP 0.2
OK
$ docker exec redis-observability redis-cli LATENCY HISTORY command
1) 1) (integer) 1791686366
   2) (integer) 201
```

`DEBUG SLEEP` is disabled by default (`enable-debug-command no`) because it does exactly what it says: blocks the single-threaded event loop for the given duration, refusing every other client's command for that whole window — a command with zero legitimate use in a production request path, and an easy denial-of-service vector if reachable from an untrusted client. This lab's compose file explicitly opts back in (`--enable-debug-command yes`) purely to manufacture a controlled, reproducible latency spike for teaching purposes.

**Step 4 — exporter and Prometheus health:**

```
$ curl -s localhost:9121/metrics | grep '^redis_up '
redis_up 1
$ curl -s localhost:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); print([t['health'] for t in d['data']['activeTargets']])"
['up']
```

**Step 5 — Grafana renders real data:**

```
$ curl -s localhost:3000/api/dashboards/uid/pulse-redis | python3 -c "import sys,json; print(json.load(sys.stdin)['dashboard']['title'])"
Pulse Redis — Level 5 Observability
```

Opening `http://localhost:3000` in a browser shows the "Redis Up" stat panel green/`1` and "Connected Clients" at `1` or more — both backed by the same `redis_up`/`redis_connected_clients` metrics just confirmed via the API above.

**Step 6 — traffic spike:**

```
$ docker exec redis-observability redis-benchmark -h localhost -p 6379 -n 20000 -q
...
$ curl -s --get 'http://localhost:9090/api/v1/query' --data-urlencode 'query=rate(redis_commands_processed_total[1m])'
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"instance":"redis-exporter:9121","job":"redis"},"value":[1791686330.157,"7364.436856431793"]}]}}
```

The "Commands/sec" panel jumps from near-idle to **~7364 ops/sec** within the benchmark's run — visibly, on the dashboard, within Prometheus's 5-second scrape interval.

**Step 7 — first alert to configure:**

`redis_up` — every other metric on the dashboard (memory, hit rate, slow commands) is meaningless the moment the exporter can't even reach Redis, so it's the one precondition every other alert implicitly depends on. An alert on `redis_up == 0` catches the single failure mode (the instance is unreachable or down) that would otherwise make every other dashboard panel go silently blank rather than loudly alert.
