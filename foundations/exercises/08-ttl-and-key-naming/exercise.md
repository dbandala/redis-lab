# Exercise 08 — TTL and Key Naming

1. Set `cache:product:9001` to `"cached-payload"`.
2. Give it a 120-second TTL, then confirm the remaining TTL.
3. Try to shorten its TTL to 30 seconds using the flag that only allows **extending** a TTL. Confirm the attempt is rejected and the TTL is (approximately) unchanged.
4. Now extend it to 300 seconds using the same flag. Confirm it succeeds this time and the TTL updates.
5. Remove the TTL entirely so the key becomes permanent, and confirm `TTL` now reports "no expiration."
6. Duplicate `user:1001` (from Lesson 05) into a new key `user:1001:backup` using a single command, then read back the backup's contents.
7. Name three new keys you'd create for a shopping-cart feature, following the colon-delimited convention (e.g. one for the cart itself, one for a per-user coupon, one for a checkout session) — no need to actually create them, just write out the key names.

Check your answers against [solutions/08-ttl-and-key-naming/solution.md](../../solutions/08-ttl-and-key-naming/solution.md).
