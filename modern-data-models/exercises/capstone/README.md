# Capstone — Pulse Discover

## Scenario

Pulse Discover is going live: a browse/search/recommendation surface for the Pulse ticketing platform, backed by Redis 8's native modern data models. You're building: a searchable, filterable event catalog (JSON + secondary indexing), event-similarity recommendations and a RAG-style support knowledge base (vector search, hybrid filtering), a live activity log processed by a consumer group (Streams), fraud-prevention guards for replayed webhooks and ticket resale (Bloom/Cuckoo filters), and a trending-now widget plus search-term analytics (Top-K, Count-Min Sketch). This capstone combines every Level 3 topic into one connected flow.

## Rubric

Your solution is complete when:
- All 10 tasks in [exercise.md](exercise.md) have been performed against the lab
- `bash verify.sh` reports `0 failed`
- You can explain why the recommendation query (task 2) and the support KB query (task 4) both use a `TAG` filter joined to a `KNN` clause with `=>` instead of running the vector search unfiltered and filtering the results afterward — i.e. you can restate Lesson 05's filter-then-rank argument in your own words for this specific scenario

Compare your work against [solutions/capstone/solution.md](../../solutions/capstone/solution.md) once you're done — not before.
