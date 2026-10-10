#!/usr/bin/env bash
# Self-check for the Level 2 capstone. Run after completing exercise.md.
set -uo pipefail

R() { docker exec redis-data-modeling redis-cli "$@"; }

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

check "geo:venues is a zset under the hood"     "$(R TYPE geo:venues)"                                        "zset"
check "geo:venues has 3 venues indexed"         "$(R ZCARD geo:venues)"                                       "3"
check "GA inventory decremented, not negative"  "$([ "$(R GET inventory:ticket:evt100:GA)" -le 48 ] && [ "$(R GET inventory:ticket:evt100:GA)" -ge 0 ] && echo yes || echo no)" "yes"
check "VIP inventory sold out"                  "$(R GET inventory:ticket:evt100:VIP)"                        "0"
check "ticketlib Function is loaded"            "$([ "$(R FUNCTION LIST | grep -c ticketlib)" -ge 1 ] && echo yes || echo no)" "yes"
check "unique visitors tracked"                 "$([ "$(R PFCOUNT hll:event:evt100:visitors:launch)" -ge 1 ] && echo yes || echo no)" "yes"
check "daily-active bitmap has activity"        "$([ "$(R BITCOUNT bitmap:dau:launch)" -ge 1 ] && echo yes || echo no)" "yes"
check "leaderboard has at least 3 fans"         "$([ "$(R ZCARD leaderboard:fans:global)" -ge 3 ] && echo yes || echo no)" "yes"
check "rate limiter key exists with a TTL"      "$([ "$(R TTL ratelimit:fixed:user:900:w0)" -gt 0 ] && echo yes || echo no)" "yes"
check "VIP reservation hash was recorded"       "$(R HGET reservation:res_launch1 user_id)"                   "900"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
