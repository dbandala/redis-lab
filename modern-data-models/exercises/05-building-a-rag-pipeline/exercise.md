# Exercise 05 — Building a RAG Retrieval Pipeline

Continue using `idx:kb` from the lesson (make sure you ran `seed-vectors.py` first).

1. Add a ninth knowledge-base document, `kb:doc9`: `title` = `"Are accessible parking spaces available?"`, `category` = `"parking"`, `text` = `"Yes, accessible parking spaces are available near the main entrance; mention it when purchasing your parking pass."`, `embedding` = `[0.2, 0.3, 0.88, 0.15]`. Confirm it's indexed with `FT.SEARCH idx:kb "@category:{parking}"`.
2. Pack the query vector `[0.266, 0.228, 0.57, 0.53]` into bytes with Python (as in the lesson) and run a plain, unfiltered `KNN 2` search against `idx:kb`. You should get one `parking` result and one `general` result back — a genuinely mixed, ambiguous top-2.
3. Run the same query vector again, this time with a `@category:{general}` pre-filter joined to the KNN clause. Which two documents come back now?
4. Run it a third time with a `@category:{parking}` pre-filter instead. Which two documents come back?
5. Suppose the real user question was *"What time do doors open, and is there parking nearby?"* — genuinely about **two** categories at once. Would a single hybrid query with one category filter answer this well? What would you do differently in a real RAG backend facing a multi-topic question like this?

Check your answers against [solutions/05-building-a-rag-pipeline/solution.md](../../solutions/05-building-a-rag-pipeline/solution.md).
