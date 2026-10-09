# Exercise 06 — Sets

1. Create `article:42:tags` with members `redis`, `database`, `nosql`.
2. Create `article:43:tags` with members `redis`, `cache`, `performance`.
3. List all members of `article:42:tags`. Check whether `"redis"` and `"postgres"` are each members (two separate checks).
4. Compute the tags common to both articles (`SINTER`), the union of both (`SUNION`), and the tags unique to article 42 (`SDIFF`, article 42 minus article 43).
5. Count the number of tags on article 42 (`SCARD`), and check `OBJECT ENCODING`.
6. Create a new set `numbers:test` containing the integers 1 through 5, and check its encoding. How does it differ from the encoding of `article:42:tags`, and why?

Check your answers against [solutions/06-sets/solution.md](../../solutions/06-sets/solution.md).
