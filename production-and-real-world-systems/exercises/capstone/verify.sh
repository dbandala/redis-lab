#!/usr/bin/env bash
# Self-check for the Level 5 capstone. Run after completing exercise.md, from this directory,
# against a freshly-started `compose/observability.yml` stack.
set -uo pipefail

cd "$(dirname "$0")"

REDIS_CONTAINER="redis-observability"

pass=0
fail=0

check() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (got '$actual', want '$expected')"
    fail=$((fail + 1))
  fi
}

check_true() {
  local desc="$1" cond="$2"
  if [ "$cond" = "true" ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    fail=$((fail + 1))
  fi
}

# --- 1. Stack is up ---
check "redis-observability responds to PING" \
  "$(docker exec "$REDIS_CONTAINER" redis-cli PING)" "PONG"

# --- 2. Prometheus reports the target healthy ---
redis_up="$(curl -s --get 'http://localhost:9090/api/v1/query' --data-urlencode 'query=redis_up' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['result'][0]['value'][1] if d['data']['result'] else '0')" 2>/dev/null)"
check "Prometheus reports redis_up == 1" "$redis_up" "1"

# --- 3. Snapshot commands_processed_total before the workload ---
before_cmds="$(curl -s localhost:9121/metrics | grep -E '^redis_commands_processed_total ' | awk '{print $2}')"

# --- Fresh scenario ---
python3 seed_pulse.py >/dev/null

# --- 4. Cache-aside populates a bounded TTL ---
python3 -c "
import pulse_capstone as pc
pool = pc.get_pool()
pc.cache_aside_get_event(pool, 'vip1')
"
ttl="$(docker exec "$REDIS_CONTAINER" redis-cli TTL pulse:cache:event:vip1)"
check_true "cache-aside TTL is set and bounded (0 < ttl <= 30)" \
  "$( [ "$ttl" -gt 0 ] && [ "$ttl" -le 30 ] && echo true || echo false )"

# --- 5. Write-through updates the cache immediately, no TTL reset needed ---
python3 -c "
import pulse_capstone as pc
pool = pc.get_pool()
pc.write_through_update_price(pool, 'vip1', '123.45')
"
cached_price="$(docker exec "$REDIS_CONTAINER" redis-cli HGET pulse:cache:event:vip1 price)"
check "write-through updates the cache immediately" "$cached_price" "123.45"

# --- 6 & 7. Lock race + fencing token ---
race_json="$(python3 race_runner.py lock_race)"
echo "race result: $race_json"

successes="$(echo "$race_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(sum(1 for v in d.values() if v['success']))
")"
check "exactly one of two concurrent claims succeeded" "$successes" "1"

remaining="$(docker exec "$REDIS_CONTAINER" redis-cli HGET pulse:db:event:vip1 vip_slots_remaining)"
check "vip_slots_remaining is exactly 0 after the race (no oversell)" "$remaining" "0"

tokens_differ="$(echo "$race_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
tokens = [v['fencing_token'] for v in d.values()]
print('true' if tokens[0] != tokens[1] else 'false')
")"
check_true "the two fencing tokens differ (the counter actually incremented)" "$tokens_differ"

winner_token="$(echo "$race_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
winner = next(v for v in d.values() if v['success'])
print(winner['fencing_token'])
")"
db_last_token="$(docker exec "$REDIS_CONTAINER" redis-cli HGET pulse:db:event:vip1 last_fencing_token)"
check "the DB's last_fencing_token matches the winning claim's token" "$db_last_token" "$winner_token"

# --- 8. Rate limiter hammer ---
rl_json="$(python3 race_runner.py rate_limit_hammer)"
echo "rate limiter result: $rl_json"
accepted="$(echo "$rl_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['accepted'])")"
rejected="$(echo "$rl_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['rejected'])")"
check "rate limiter accepted exactly the configured limit (3)" "$accepted" "3"
check_true "rate limiter rejected at least one call beyond the limit" \
  "$( [ "$rejected" -gt 0 ] && echo true || echo false )"

# --- 9. Job queue: enqueue -> pending -> processed -> marker ---
winner_agent="$(echo "$race_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(next(k for k, v in d.items() if v['success']))
")"
RACE_JSON="$race_json" python3 -c "
import json, os
import pulse_capstone as pc
pool = pc.get_pool()
race = json.loads(os.environ['RACE_JSON'])
winner = next(v for v in race.values() if v['success'])
pc.enqueue_notification(pool, winner)
"
pending_len="$(docker exec "$REDIS_CONTAINER" redis-cli LLEN pulse:queue:notifications:pending)"
check_true "notification queued (pending list non-empty) immediately post-claim" \
  "$( [ "$pending_len" -gt 0 ] && echo true || echo false )"

python3 -c "
import pulse_capstone as pc
pool = pc.get_pool()
pc.process_notifications(pool)
"
pending_len_after="$(docker exec "$REDIS_CONTAINER" redis-cli LLEN pulse:queue:notifications:pending)"
check "pending list empty after processing" "$pending_len_after" "0"

notified_marker="$(docker exec "$REDIS_CONTAINER" redis-cli GET "pulse:notified:$winner_agent")"
check_true "notified marker key exists for the winning agent" \
  "$( [ -n "$notified_marker" ] && echo true || echo false )"

# --- 10. Memo structural check ---
required_headings=("## Dataset vs Memory Budget" "## Durability Requirements" "## Transactional Needs" "## Recommendation")
memo_ok="true"
for heading in "${required_headings[@]}"; do
  if ! grep -qF "$heading" memo.md 2>/dev/null; then
    memo_ok="false"
  fi
done
check_true "memo.md contains all required headings" "$memo_ok"

# --- 11. Final traffic re-check ---
after_cmds="$(curl -s localhost:9121/metrics | grep -E '^redis_commands_processed_total ' | awk '{print $2}')"
delta_ok="$(python3 -c "print('true' if float('$after_cmds') > float('$before_cmds') else 'false')")"
check_true "redis_commands_processed_total increased during this run (the dashboard would show it)" "$delta_ok"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
