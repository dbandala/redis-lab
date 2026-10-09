# Exercise 02 — Installing and Running

1. Start the lab environment and confirm both containers are running:
   ```
   <!-- TODO: bring up the stack -->
   <!-- TODO: list running compose services -->
   ```
2. Ping Redis through `redis-cli` running inside the `redis-foundations` container:
   ```
   <!-- TODO -->
   ```
3. Set a throwaway key and read it back, using `redis-cli` directly from your shell (one command per line, no interactive session):
   ```
   <!-- TODO: SET hello world -->
   <!-- TODO: GET hello -->
   ```
4. Open RedisInsight in your browser, connect it to the `redis` service, and confirm you can see the `hello` key you just created in the key browser.
5. Stop the lab environment without deleting its data volumes.
   ```
   <!-- TODO -->
   ```

Check your answers against [solutions/02-installing-and-running/solution.md](../../solutions/02-installing-and-running/solution.md).
