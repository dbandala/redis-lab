#!/usr/bin/env bash
# Simulates a second client racing you to a watched key. Run this in a
# SECOND terminal while your WATCH/MULTI/EXEC transaction is paused,
# to force EXEC to abort.
#
# Usage: ./simulate-concurrent-update.sh <key> <decrby-amount> [delay-seconds]
set -euo pipefail

key="${1:?usage: simulate-concurrent-update.sh <key> <decrby-amount> [delay-seconds]}"
amount="${2:?usage: simulate-concurrent-update.sh <key> <decrby-amount> [delay-seconds]}"
delay="${3:-0}"

if [ "$delay" -gt 0 ]; then
  echo "Waiting ${delay}s before the concurrent update..."
  sleep "$delay"
fi

echo "Decrementing $key by $amount from a second connection..."
docker exec redis-data-modeling redis-cli DECRBY "$key" "$amount"
