# Pulse Production-Readiness Memo — Ticket Purchases

Apply Lesson 08's framework to Pulse's ticket-purchase data. Replace each bracketed prompt
with your own 2–4 sentence analysis; this is the same memo Lesson 08's exercise asked for —
if you already wrote it there, paste it in here.

## Dataset vs Memory Budget

[Does the ticket-purchase dataset fit comfortably in memory today? Is "does it fit" even the
deciding factor for this dataset, or do the other three conditions settle it first?]

## Durability Requirements

[Does a confirmed ticket purchase need a durability guarantee beyond what `appendfsync always`
gives you? What's the concrete failure mode if that guarantee isn't met?]

## Transactional Needs

[Does confirming a purchase require more than one record to change atomically together? Name
the specific records, and explain why Redis's own primitives (`MULTI`/`EXEC`/`WATCH`) do or
don't cover it.]

## Recommendation

[Where should ticket-purchase data actually live, and what role — if any — does Redis still
play for it? Reference Lesson 03's cache-aside/write-through boundary and Lesson 04's lock if
relevant.]
