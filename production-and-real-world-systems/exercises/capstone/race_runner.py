"""Drives the concurrency-sensitive capstone checks and prints JSON for verify.sh to parse.

Run from the exercises/capstone/ directory: `python3 race_runner.py <mode>`
Modes: lock_race | rate_limit_hammer
"""
import json
import sys
import threading

import pulse_capstone as pc

EVENT_ID = "vip1"


def lock_race():
    pool = pc.get_pool()
    results = {}

    def attempt(agent_id):
        results[agent_id] = pc.try_claim_vip_slot(pool, EVENT_ID, agent_id)

    t1 = threading.Thread(target=attempt, args=("agent:alice",))
    t2 = threading.Thread(target=attempt, args=("agent:bob",))
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    print(json.dumps(results))


def rate_limit_hammer(agent_id="agent:hammer", calls=10):
    pool = pc.get_pool()
    outcomes = [pc.rate_limited(pool, agent_id) for _ in range(calls)]
    accepted = sum(1 for was_limited in outcomes if not was_limited)
    rejected = sum(1 for was_limited in outcomes if was_limited)
    print(json.dumps({"accepted": accepted, "rejected": rejected, "outcomes": outcomes}))


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "lock_race"
    if mode == "lock_race":
        lock_race()
    elif mode == "rate_limit_hammer":
        rate_limit_hammer()
    else:
        print(f"unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)
