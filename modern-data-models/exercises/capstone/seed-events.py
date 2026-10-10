#!/usr/bin/env python3
"""Seed the Pulse Discover capstone scenario: an event catalog with a hybrid
search+vector index, and a support knowledge base with its own hybrid index.

Pure standard library, no third-party dependencies. All keys live under the
`discover:` prefix so this script is self-contained and safe to run on a
fresh lab, independent of whatever state the lessons/exercises left behind.

Usage:
    python3 seed-events.py | docker exec -i redis-modern-data-models redis-cli --no-raw
"""

import json

EVENTS = [
    {
        "key": "discover:event:d1",
        "name": "Night Lights Festival",
        "venue": "Riverside Park",
        "city": "Austin",
        "tags": ["music", "outdoor", "family-friendly"],
        "price": 79.5,
        "capacity": 5000,
        "vibe": [0.9, 0.1, 0.8, 0.7],
    },
    {
        "key": "discover:event:d2",
        "name": "Sunset Jazz Night",
        "venue": "Blue Note Hall",
        "city": "Denver",
        "tags": ["jazz", "indoor", "21+"],
        "price": 45,
        "capacity": 800,
        "vibe": [0.2, 0.9, 0.3, 0.4],
    },
    {
        "key": "discover:event:d3",
        "name": "Indie Rock Rally",
        "venue": "Mohawk",
        "city": "Austin",
        "tags": ["rock", "outdoor"],
        "price": 60,
        "capacity": 3000,
        "vibe": [0.7, 0.2, 0.6, 0.6],
    },
    {
        "key": "discover:event:d4",
        "name": "Downtown Jazz Brunch",
        "venue": "Civic Hall",
        "city": "Denver",
        "tags": ["jazz", "indoor", "brunch"],
        "price": 35,
        "capacity": 150,
        "vibe": [0.1, 0.9, 0.2, 0.3],
    },
    {
        "key": "discover:event:d5",
        "name": "Lantern Night Market",
        "venue": "Fairgrounds",
        "city": "Austin",
        "tags": ["market", "family-friendly", "outdoor"],
        "price": 15,
        "capacity": 10000,
        "vibe": [0.8, 0.3, 0.9, 0.8],
    },
    {
        "key": "discover:event:d6",
        "name": "Acoustic Singer-Songwriter Night",
        "venue": "The Parlor",
        "city": "Austin",
        "tags": ["acoustic", "indoor"],
        "price": 25,
        "capacity": 200,
        "vibe": [0.15, 0.95, 0.25, 0.25],
    },
]

KB_DOCS = [
    {
        "key": "discover:kb:k1",
        "title": "How do I get a refund for a cancelled show?",
        "category": "refunds",
        "text": (
            "If an event is cancelled, Pulse automatically refunds the full "
            "ticket price to your original payment method within 5-7 "
            "business days."
        ),
        "embedding": [0.9, 0.1, 0.1, 0.2],
    },
    {
        "key": "discover:kb:k2",
        "title": "Can I get a refund if I just change my mind?",
        "category": "refunds",
        "text": (
            "Tickets are non-refundable for change-of-mind cancellations, "
            "but you can resell them through Pulse's official resale "
            "marketplace."
        ),
        "embedding": [0.85, 0.15, 0.15, 0.25],
    },
    {
        "key": "discover:kb:k3",
        "title": "Requesting a wheelchair-accessible seating area",
        "category": "accessibility",
        "text": (
            "Select Accessible Seating during checkout, or contact venue "
            "support at least 48 hours before the event to arrange "
            "accommodations."
        ),
        "embedding": [0.1, 0.9, 0.2, 0.3],
    },
    {
        "key": "discover:kb:k4",
        "title": "Do you provide ASL interpreters?",
        "category": "accessibility",
        "text": (
            "ASL interpretation is available on request for most venues; "
            "submit a request through your order confirmation page at "
            "least one week in advance."
        ),
        "embedding": [0.15, 0.85, 0.25, 0.3],
    },
    {
        "key": "discover:kb:k5",
        "title": "Where can I park near the venue?",
        "category": "parking",
        "text": (
            "Most venues list on-site or partner parking under the event's "
            "Getting There tab; some offer prepaid parking passes at "
            "checkout."
        ),
        "embedding": [0.2, 0.3, 0.9, 0.1],
    },
    {
        "key": "discover:kb:k6",
        "title": "Is parking included with my ticket?",
        "category": "parking",
        "text": (
            "Parking is not included by default; look for a Parking Pass "
            "add-on when purchasing your ticket if the venue offers one."
        ),
        "embedding": [0.25, 0.35, 0.85, 0.15],
    },
    {
        "key": "discover:kb:k7",
        "title": "How early should I arrive before the show?",
        "category": "general",
        "text": (
            "Doors typically open 60-90 minutes before the listed show "
            "time; check your ticket confirmation for venue-specific "
            "arrival guidance."
        ),
        "embedding": [0.3, 0.2, 0.2, 0.85],
    },
    {
        "key": "discover:kb:k8",
        "title": "What items are prohibited inside the venue?",
        "category": "general",
        "text": (
            "Outside food and drinks, professional cameras, and large bags "
            "are typically prohibited; check each venue's specific policy "
            "on its page."
        ),
        "embedding": [0.25, 0.15, 0.25, 0.9],
    },
    {
        "key": "discover:kb:k9",
        "title": "Are accessible parking spaces available?",
        "category": "parking",
        "text": (
            "Yes, accessible parking spaces are available near the main "
            "entrance; mention it when purchasing your parking pass."
        ),
        "embedding": [0.2, 0.3, 0.88, 0.15],
    },
]


def redis_cli_args(*args):
    """Render one redis-cli command line for its stdin/pipe-mode parser.

    A literal apostrophe inside a single-quoted argument must be written as
    a backslash directly followed by an apostrophe (\\') for redis-cli's own
    line parser -- the shell's close-quote/escape/reopen trick does not
    apply here, since this line is never interpreted by a shell.
    """
    parts = []
    for arg in args:
        text = str(arg)
        if " " in text or text.startswith("{") or text.startswith("["):
            escaped = text.replace("\\", "\\\\").replace("'", "\\'")
            parts.append("'" + escaped + "'")
        else:
            parts.append(text)
    return " ".join(parts)


for doc in EVENTS:
    body = {k: v for k, v in doc.items() if k != "key"}
    print(redis_cli_args("JSON.SET", doc["key"], "$", json.dumps(body)))

print(
    redis_cli_args(
        "FT.CREATE", "idx:discover_events", "ON", "JSON", "PREFIX", "1", "discover:event:",
        "SCHEMA",
        "$.name", "AS", "name", "TEXT",
        "$.city", "AS", "city", "TAG",
        "$.tags[*]", "AS", "tags", "TAG",
        "$.price", "AS", "price", "NUMERIC",
        "$.capacity", "AS", "capacity", "NUMERIC",
        "$.vibe", "AS", "vibe", "VECTOR", "HNSW", "6",
        "TYPE", "FLOAT32", "DIM", "4", "DISTANCE_METRIC", "COSINE",
    )
)

for doc in KB_DOCS:
    body = {k: v for k, v in doc.items() if k != "key"}
    print(redis_cli_args("JSON.SET", doc["key"], "$", json.dumps(body)))

print(
    redis_cli_args(
        "FT.CREATE", "idx:discover_kb", "ON", "JSON", "PREFIX", "1", "discover:kb:",
        "SCHEMA",
        "$.title", "AS", "title", "TEXT",
        "$.category", "AS", "category", "TAG",
        "$.text", "AS", "text", "TEXT",
        "$.embedding", "AS", "embedding", "VECTOR", "HNSW", "6",
        "TYPE", "FLOAT32", "DIM", "4", "DISTANCE_METRIC", "COSINE",
    )
)
