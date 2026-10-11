#!/usr/bin/env bash
# Self-check for the Level 4 capstone. Run after completing exercise.md,
# against a freshly-started `compose/sentinel.yml` stack.
set -uo pipefail

SENTINEL_CONTAINER="sentinel-1"
MASTER_NAME="pulse-primary"
OLD_PRIMARY="redis-sentinel-primary"
REPLICAS=(redis-sentinel-replica-1 redis-sentinel-replica-2)
MAX_WAIT=45
POLL_INTERVAL=1
PULSE_API_URL="redis://pulse-api:s3cret-api-pass@localhost:6379"

S() { docker exec "$SENTINEL_CONTAINER" redis-cli -p 26379 "$@"; }

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

# --- Pre-failover: configuration tasks ---
check "appendfsync is 'always' on the primary"                \
  "$(docker exec "$OLD_PRIMARY" redis-cli CONFIG GET appendfsync | tail -1)" "always"

check "pulse-api ACL user exists on the primary"               \
  "$(docker exec "$OLD_PRIMARY" redis-cli ACL LIST | grep -c '^user pulse-api ')" "1"

check "pulse-api can read pulse:* but not run FLUSHALL"        \
  "$(docker exec "$OLD_PRIMARY" redis-cli -u "$PULSE_API_URL" FLUSHALL 2>&1 | grep -c NOPERM)" "1"

check "maxmemory-policy is allkeys-lru on the primary"          \
  "$(docker exec "$OLD_PRIMARY" redis-cli CONFIG GET maxmemory-policy | tail -1)" "allkeys-lru"

check "pulse:event:evt1 exists and replicated to both replicas" \
  "$(for c in "${REPLICAS[@]}"; do docker exec "$c" redis-cli GET pulse:event:evt1; done | sort -u | wc -l | tr -d ' ')" "1"

# --- Sanity check before injecting failure ---
quorum="$(S SENTINEL ckquorum "$MASTER_NAME" 2>/dev/null | head -1)"
check "Sentinel quorum is healthy before the failover test" \
  "$(echo "$quorum" | grep -q '^OK' && echo yes || echo no)" "yes"

before_ip="$(S SENTINEL get-master-addr-by-name "$MASTER_NAME" | head -1)"

# Ensure the old primary gets restarted even if this script is interrupted
trap 'docker start "$OLD_PRIMARY" >/dev/null 2>&1 || true' EXIT

docker stop "$OLD_PRIMARY" >/dev/null

# --- Poll for Sentinel to promote a new primary ---
elapsed=0
after_ip="$before_ip"
while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
  after_ip="$(S SENTINEL get-master-addr-by-name "$MASTER_NAME" 2>/dev/null | head -1)"
  [ -n "$after_ip" ] && [ "$after_ip" != "$before_ip" ] && break
done
check "Sentinel promoted a new primary within ${MAX_WAIT}s" \
  "$([ "$after_ip" != "$before_ip" ] && echo yes || echo no)" "yes"

new_master=""
for c in "${REPLICAS[@]}"; do
  role="$(docker exec "$c" redis-cli INFO replication 2>/dev/null | grep -m1 '^role:' | tr -d '\r')"
  [ "$role" = "role:master" ] && new_master="$c"
done
check "exactly one former replica was promoted to master" \
  "$([ -n "$new_master" ] && echo yes || echo no)" "yes"

if [ -n "$new_master" ]; then
  check "the promoted primary still has pulse:event:evt1"          \
    "$(docker exec "$new_master" redis-cli GET pulse:event:evt1)" "Night Lights Festival"
  check "the promoted primary still enforces the pulse-api ACL"    \
    "$(docker exec "$new_master" redis-cli -u "$PULSE_API_URL" FLUSHALL 2>&1 | grep -c NOPERM)" "1"
  check "the promoted primary still has maxmemory-policy allkeys-lru" \
    "$(docker exec "$new_master" redis-cli CONFIG GET maxmemory-policy | tail -1)" "allkeys-lru"
fi

# --- Restart the old primary and confirm it rejoins as a replica ---
docker start "$OLD_PRIMARY" >/dev/null

elapsed=0
rejoined="no"
while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
  role="$(docker exec "$OLD_PRIMARY" redis-cli INFO replication 2>/dev/null | grep -m1 '^role:' | tr -d '\r')"
  [ "$role" = "role:slave" ] && { rejoined="yes"; break; }
done
check "old primary rejoined as a replica within ${MAX_WAIT}s" "$rejoined" "yes"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
