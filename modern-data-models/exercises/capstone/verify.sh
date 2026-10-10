#!/usr/bin/env bash
# Self-check for the Level 3 capstone. Run after completing exercise.md.
set -uo pipefail

R() { docker exec redis-modern-data-models redis-cli "$@"; }

knn_top_key() {
  # knn_top_key <idx> <filter-prefix> <field> <v1> <v2> <v3> <v4>
  local idx="$1" filter="$2" field="$3" v1="$4" v2="$5" v3="$6" v4="$7"
  python3 -c "import struct,sys; sys.stdout.buffer.write(struct.pack('<4f', $v1, $v2, $v3, $v4))" \
    | docker exec -i redis-modern-data-models redis-cli -x FT.SEARCH "$idx" \
        "${filter}=>[KNN 1 @${field} \$BLOB AS score]" DIALECT 2 RETURN 0 PARAMS 2 BLOB \
    | sed -n '2p'
}

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

check "idx:discover_events indexes all 6 catalog events"     "$(R FT.SEARCH idx:discover_events '*' LIMIT 0 0)" "6"
check "idx:discover_kb indexes all 9 support docs"           "$(R FT.SEARCH idx:discover_kb '*' LIMIT 0 0)"     "9"
check "hybrid rec query returns the high-energy Austin event" "$(knn_top_key idx:discover_events '@city:{Austin}' vibe 0.85 0.15 0.75 0.75)" "discover:event:d1"
check "support KB hybrid query answers the refund question"   "$(knn_top_key idx:discover_kb '@category:{refunds}' embedding 0.88 0.12 0.12 0.2)" "discover:kb:k1"
check "activity stream has at least 5 entries"                "$([ "$(R XLEN stream:pulse:discover:activity)" -ge 5 ] && echo yes || echo no)" "yes"
check "consumer group has zero pending entries"               "$(R XPENDING stream:pulse:discover:activity grp:discover:analytics | head -1)" "0"
check "webhook retry is detected by the Bloom filter"         "$(R BF.EXISTS webhooks:seen:discover whk_launch_01)" "1"
check "TCK-7001 was unlisted after the refund"                "$(R CF.EXISTS resale:listed:discover TCK-7001)"      "0"
check "TCK-7002 is still listed"                              "$(R CF.EXISTS resale:listed:discover TCK-7002)"      "1"
check "trending-now surfaces d5 as the top event"             "$(R TOPK.LIST trending:events:discover | head -1)"   "d5"
check "search-analytics CMS tracked 'jazz night' frequency"   "$(R CMS.QUERY search:queries:discover 'jazz night')" "5"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
