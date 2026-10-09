#!/usr/bin/env bash
# Self-check for the Level 1 capstone. Run after completing exercise.md.
set -uo pipefail

R() { docker exec redis-foundations redis-cli "$@"; }

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

check "user:1 is a hash"             "$(R TYPE user:1)"                                     "hash"
check "user:1 has a name field"      "$(R HEXISTS user:1 name)"                              "1"
check "session:demo exists"          "$(R EXISTS session:demo)"                              "1"
check "session:demo was persisted"   "$(R TTL session:demo)"                                 "-1"
check "article:1:tags is a set"      "$(R TYPE article:1:tags)"                              "set"
check "leaderboard has entries"      "$([ "$(R ZCARD leaderboard:articles:views)" -ge 1 ] && echo yes || echo no)" "yes"
check "feed:global capped at <=20"   "$([ "$(R LLEN feed:global)" -le 20 ] && echo yes || echo no)" "yes"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
