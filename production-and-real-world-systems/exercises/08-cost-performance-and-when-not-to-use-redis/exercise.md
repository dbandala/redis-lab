# Exercise 08 — Cost, Performance & When NOT to Use Redis

This is a design-doc exercise — no local stack, no `verify.sh`. Answers in prose.

1. Apply the lesson's four-condition framework to each of these Pulse data categories, one sentence of justification per condition (skip to "no, doesn't exceed Redis" once a condition clearly doesn't apply — you don't need all four spelled out if the first one already settles it): (a) a per-session shopping cart during active browsing, (b) a confirmed, paid ticket purchase record, (c) a venue's full-resolution seating-chart image, (d) a live view counter on an event page.
2. For the one category above where Redis clearly should **not** be the primary store, name what you'd use instead and what role (if any) Redis still plays for that data.
3. In 2–3 sentences, explain why Redis costs more per GB than a disk-backed store, and why that premium is nonetheless worth paying for Pulse's rate-limit counters specifically.
4. Write a short memo (headings: `## Dataset vs Memory Budget`, `## Durability Requirements`, `## Transactional Needs`, `## Recommendation`) applying this framework to Pulse's ticket-purchase data end-to-end. This is the same memo the capstone requires — if you complete it here, carry it forward.
