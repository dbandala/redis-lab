# Exercise 01 — Observability & Monitoring

Bring up this lesson's stack (not the base stack): `docker compose -f compose/observability.yml up -d`.

1. Run `INFO stats` and `INFO memory` against `redis-observability`. Name one field from each section you'd want paged on if it crossed a threshold in production, and why.
2. Set `slowlog-log-slower-than` to `0`, run a couple of commands, then read them back with `SLOWLOG GET`. Identify the `duration_microseconds` field in one entry. Reset the threshold to its default (`10000`) and `SLOWLOG RESET` afterward.
3. Set `latency-monitor-threshold` to `100`, then run `DEBUG SLEEP 0.2`. Confirm `LATENCY HISTORY command` shows one entry with a duration at or above `200`. Explain in one sentence why `DEBUG SLEEP` is disabled by default in a normal Redis deployment.
4. Confirm the exporter can reach the target: `curl -s localhost:9121/metrics | grep '^redis_up '` should show `1`. Then confirm Prometheus itself considers the target healthy via its targets API or UI at `localhost:9090/targets`.
5. Open `http://localhost:3000` (no login needed) and confirm the "Pulse Redis — Level 5 Observability" dashboard renders with real (non-zero, non-"No data") values on at least the "Redis Up" and "Connected Clients" panels.
6. Generate traffic with `docker exec redis-observability redis-benchmark -h localhost -p 6379 -n 20000 -q`, then watch the "Commands/sec" panel. Confirm it visibly spikes within about 10 seconds of running the benchmark.
7. Name which single metric from this lesson you'd configure an alert on first for a production Pulse deployment, and why that one before any other.

Compare your work against [solution.md](solution.md) once you're done — not before.
