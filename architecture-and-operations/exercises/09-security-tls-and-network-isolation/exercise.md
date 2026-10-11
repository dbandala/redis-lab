# Exercise 09 — TLS & Network Isolation

Lab for this exercise: run `./scripts/generate-certs.sh` once if you haven't already, then `docker compose -f compose/tls.yml up -d`.

1. List `certs/` and identify which three files are *certificates* (shareable, not secret) and which three are *private keys* (never shareable). Which one file is shared by both the server and client cert's issuance?
2. Try `docker exec redis-tls redis-cli -p 6443 PING` — no `--tls` flag at all, talking plaintext to the TLS port. What happens, and why is this a different failure than simply "connection refused"?
3. Try again with `--tls -p 6443` but **no** `--cacert` flag. What's the error, and what is `redis-cli` unable to do without being told which CA to trust?
4. Try again with `--tls --cacert /tls/ca.crt -p 6443` — correct CA, still no client cert. What's the error, and which server config flag specifically causes this one (not generic TLS, something more specific)?
5. Now the full correct form: `--tls --cert /tls/client.crt --key /tls/client.key --cacert /tls/ca.crt -p 6443`. Confirm `PONG`.
6. Run a throwaway container **not** attached to `redis-lab-tls_default` and try to resolve `redis-tls` by name. Then run one **attached** to that network (`docker run --rm --network redis-lab-tls_default ...`) and confirm it resolves and can complete the full TLS handshake from step 5.
7. Conceptual: this lab's `tls.yml` doesn't set `requirepass` or any ACL user — anyone who gets past the TLS handshake can run any command. If Pulse combined this lesson with Lesson 08, where in the connection sequence would ACL enforcement happen relative to the TLS handshake — before, during, or strictly after? What does that ordering imply about whether TLS alone (no ACL) or ACLs alone (no TLS) is the bigger gap to leave open in production?

Check your answers against [solutions/09-security-tls-and-network-isolation/solution.md](../../solutions/09-security-tls-and-network-isolation/solution.md).
