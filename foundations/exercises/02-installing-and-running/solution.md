# Solution 02 — Installing and Running

1. Start the stack and list services:
   ```
   $ docker compose up -d
   $ docker compose ps
   NAME                       IMAGE                      STATUS
   redis-foundations          redis:8.10.1               Up
   redisinsight-foundations   redis/redisinsight:3.8.0   Up
   ```
2. Ping Redis:
   ```
   $ docker exec -it redis-foundations redis-cli PING
   PONG
   ```
3. Set and read a key:
   ```
   $ docker exec redis-foundations redis-cli SET hello world
   OK
   $ docker exec redis-foundations redis-cli GET hello
   world
   ```
4. In RedisInsight (`http://localhost:8001`), add a database with host `redis`, port `6379`. The key browser should show one key, `hello`, of type `string`, with value `world`.
5. Stop the stack, keeping data:
   ```
   $ docker compose stop
   ```
   (`docker compose down` also stops and removes containers but keeps named volumes; only `docker compose down -v` deletes the data — see the module README's teardown section.)
