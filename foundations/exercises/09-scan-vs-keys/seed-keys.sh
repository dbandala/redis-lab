#!/usr/bin/env bash
# Seeds 50 demo keys so there's something worth iterating over with SCAN/KEYS.
set -euo pipefail

for i in $(seq 1 50); do
  docker exec redis-foundations redis-cli SET "demo:key:$i" "$i" > /dev/null
done

echo "Seeded 50 keys under demo:key:*"
