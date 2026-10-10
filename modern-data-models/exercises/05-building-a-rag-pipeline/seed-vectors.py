#!/usr/bin/env python3
"""Seed the Pulse support knowledge base used by Lesson 05 / its exercise.

Pure standard library, no third-party dependencies, no network calls. The
"embedding" vectors below are hand-picked 4-dimensional toy vectors (not real
model output) that deliberately cluster by category, so KNN queries against
them behave the way a real embedding model's output would: semantically
similar documents end up close together in vector space.

Usage:
    python3 seed-vectors.py | docker exec -i redis-modern-data-models redis-cli --no-raw
"""

import json

DOCS = [
    {
        "key": "kb:doc1",
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
        "key": "kb:doc2",
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
        "key": "kb:doc3",
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
        "key": "kb:doc4",
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
        "key": "kb:doc5",
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
        "key": "kb:doc6",
        "title": "Is parking included with my ticket?",
        "category": "parking",
        "text": (
            "Parking is not included by default; look for a Parking Pass "
            "add-on when purchasing your ticket if the venue offers one."
        ),
        "embedding": [0.25, 0.35, 0.85, 0.15],
    },
    {
        "key": "kb:doc7",
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
        "key": "kb:doc8",
        "title": "What items are prohibited inside the venue?",
        "category": "general",
        "text": (
            "Outside food and drinks, professional cameras, and large bags "
            "are typically prohibited; check each venue's specific policy "
            "on its page."
        ),
        "embedding": [0.25, 0.15, 0.25, 0.9],
    },
]


def redis_cli_args(*args):
    """Render one redis-cli command line for its stdin/pipe-mode parser.

    redis-cli's own line parser (not the shell's) handles single-quoted
    arguments with its own escape rule: a literal apostrophe inside a
    single-quoted argument is written as a backslash followed directly by
    an apostrophe (\\'), not the shell's close-quote/escape/reopen trick.
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


for doc in DOCS:
    body = {k: v for k, v in doc.items() if k != "key"}
    print(redis_cli_args("JSON.SET", doc["key"], "$", json.dumps(body)))

print(
    redis_cli_args(
        "FT.CREATE", "idx:kb", "ON", "JSON", "PREFIX", "1", "kb:",
        "SCHEMA",
        "$.title", "AS", "title", "TEXT",
        "$.category", "AS", "category", "TAG",
        "$.text", "AS", "text", "TEXT",
        "$.embedding", "AS", "embedding", "VECTOR", "HNSW", "6",
        "TYPE", "FLOAT32", "DIM", "4", "DISTANCE_METRIC", "COSINE",
    )
)
