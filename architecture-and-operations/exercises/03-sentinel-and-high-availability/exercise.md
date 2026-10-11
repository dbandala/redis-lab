# Exercise 03 — Sentinel & High Availability

Lab for this exercise: `compose/sentinel.yml` (3 Redis nodes + `sentinel-1`/`sentinel-2`/`sentinel-3`). Bring it up with `docker compose -f compose/sentinel.yml up -d` if it isn't already running.

1. Run `SENTINEL ckquorum pulse-primary` against `sentinel-1`. What does the response tell you, and which number in `sentinel.conf.tpl` does it depend on?
2. Run `SENTINEL get-master-addr-by-name pulse-primary`. Confirm the IP matches `redis-sentinel-primary`'s address (cross-check with `docker exec redis-sentinel-primary redis-cli INFO replication`).
3. `docker stop redis-sentinel-primary`. Poll `SENTINEL get-master-addr-by-name pulse-primary` every second. How many seconds until the address changes? Which config value in `sentinel.conf.tpl` determines that delay?
4. Find out which node Sentinel promoted by running `INFO replication` against both remaining Redis nodes and looking for `role:master`.
5. `docker start redis-sentinel-primary`. Poll its `INFO replication` output every second. How many seconds until it reports `role:slave`? Which config value determines *this* delay (it's a different one than task 3)?
6. Conceptual: this lab sets `sentinel monitor pulse-primary redis-sentinel-primary 6379 2` with exactly 3 Sentinels running. If only 1 Sentinel were running instead of 3, could a failover still happen at all? What does quorum `2` actually require that a single Sentinel can't provide on its own?

Check your answers against [solutions/03-sentinel-and-high-availability/solution.md](../../solutions/03-sentinel-and-high-availability/solution.md).
