#!/usr/bin/env bash
# Pushes 5,000 elements onto biglist:demo in reasonably-sized batches,
# so Lesson 10 has something big enough to make an O(N) full-range read measurable.
set -euo pipefail

docker exec redis-foundations redis-cli DEL biglist:demo > /dev/null

for batch_start in $(seq 1 500 5000); do
  batch_end=$((batch_start + 499))
  values=$(seq "$batch_start" "$batch_end")
  # shellcheck disable=SC2086
  docker exec -i redis-foundations redis-cli RPUSH biglist:demo $values > /dev/null
done

echo "Seeded biglist:demo with 5000 elements"
