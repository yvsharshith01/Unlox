-- =====================================================================
-- THE UNLOX ACADEMY - Week 4 Weekly Assessment
-- Joins, Subqueries, Windows & CTEs  |  Dataset: bookmart
-- =====================================================================
-- Section B answers below are computed directly against the actual
-- bookmart_setup.sql data (10 authors / 25 books / 40 sales). Still
-- worth re-running each query yourself in Workbench so you can explain
-- how you got each number - that's the actual point of the exercise.
-- =====================================================================


-- =====================================================================
-- SECTION A - THEORY  (write only the letter)
-- =====================================================================
-- A1. b  -- INNER JOIN returns only matched rows; LEFT JOIN returns all
--          left-table rows with NULL for non-matches.
-- A2. c  -- Restarts the aggregate calculation for each partition while
--          keeping all input rows (window functions don't collapse rows).
-- A3. c  -- NATURAL JOIN silently joins on ALL same-named columns; a
--          schema change (new shared column name) can silently change
--          which columns it joins on.
-- A4. b  -- Prefer UNION ALL when the two queries can't produce
--          overlapping rows, or when performance matters more than
--          deduplication (UNION ALL skips the dedup sort/hash step).
-- A5. b  -- If the NOT IN subquery returns any NULL, the whole NOT IN
--          comparison evaluates to UNKNOWN for every row, so the query
--          silently returns zero rows.
-- A6. b  -- Correlated subquery: inner query references a column from
--          the outer query, so it re-executes once per outer row.
-- A7. b  -- WHERE is evaluated before window functions in logical query
--          processing order, so a window-function alias doesn't exist
--          yet when WHERE runs (use a subquery/CTE and filter outside).
-- A8. b  -- CTE = a named temporary result set defined with WITH,
--          scoped only to the query it's attached to.


-- =====================================================================
-- SECTION B - OUTPUT PREDICTION
-- =====================================================================

-- B1. SELECT * FROM books b INNER JOIN authors a ON b.author_id = a.author_id;
-- Answer: 25 rows.
-- Every book has a non-null author_id (FK), and every author has at
-- least one book, so each of the 25 books matches exactly one author.

-- B2. SELECT a.name FROM authors a LEFT JOIN books b ON a.author_id = b.author_id
--     WHERE b.book_id IS NULL;
-- Answer: 0 rows.
-- The brief states every author has at least one book (LEFT JOIN
-- authors->books always returns exactly 25 rows, never 26), so no
-- author is ever left unmatched -> the IS NULL filter matches nothing.

-- B3. SELECT a.name AS author, m.name AS mentor FROM authors a
--     JOIN authors m ON a.mentor_id = m.author_id;
-- Answer: 3 rows - the three stated mentor relationships:
--   Preeti Shenoy  -> Chetan Bhagat
--   Alex           -> Yuval Harari
--   Malcolm Gladwell -> Yuval Harari
-- (Only these 3 authors have a non-NULL mentor_id.)

-- B4. UNION of "Indian authors" and "authors with a Mythology book".
-- Answer: 5 rows.
-- The 5 Indian authors are Chetan Bhagat, Amish Tripathi, Ruskin Bond,
-- Preeti Shenoy, and Devdutt Pattanaik. The only two authors with
-- Mythology-genre books are Amish Tripathi (Immortals of Meluha,
-- Secret of the Nagas, Oath of the Vayuputras) and Devdutt Pattanaik
-- (Jaya, Sita, My Gita) - both already Indian. So UNION adds no new
-- names; the result is the same 5 Indian authors.

-- B5. SELECT COUNT(*) FROM books WHERE price > (SELECT AVG(price) FROM books);
-- Answer: 13 rows.
-- The 25 book prices sum to 9675, so AVG(price) = 387.00. The 13 books
-- priced above 387 are: Oath of the Vayuputras (399), Jaya (499),
-- Sita (449), My Gita (399), Sapiens (499), Homo Deus (599),
-- 21 Lessons (549), The Silent Patient (399), The Maidens (449),
-- Outliers (449), Blink (399), Talking to Strangers (549),
-- The Wager (599).

-- B6. SELECT * FROM books b WHERE NOT EXISTS
--     (SELECT 1 FROM sales s WHERE s.book_id = b.book_id);
-- Answer: 15 rows.
-- Stated directly in the brief: only 10 of the 25 books have ever been
-- sold, so 15 books have never appeared in a sale.

-- B7. Top-selling book by total quantity (SUM(quantity) DESC, LIMIT 1).
-- Answer: Atomic Habits (book_id 115), total_qty = 30.
-- Its 8 sales (5+3+6+2+3+5+4+2) sum to 30, well ahead of the next
-- closest: Sapiens/Rich Dad Poor Dad at 13 each.

-- B8. RANK() OVER (PARTITION BY genre ORDER BY price DESC) for Business genre.
-- Answer (no ties in this genre, so ranks run 1-4 with no gaps):
--   Talking to Strangers  549  -> rank 1
--   Outliers               449  -> rank 2
--   Blink                   399  -> rank 3
--   Rich Dad Poor Dad       299  -> rank 4


-- =====================================================================
-- SECTION C - APPLIED SQL
-- =====================================================================

-- ---- C1 - Basic Joins ----

-- C1. INNER JOIN: each book's title alongside its author's name.
SELECT b.title, a.name AS author_name
FROM books b
INNER JOIN authors a ON b.author_id = a.author_id;

-- C2. LEFT JOIN: every author's name + every book they've written.
--     Authors with no books still appear once, with NULL book columns.
SELECT a.name AS author_name, b.title
FROM authors a
LEFT JOIN books b ON a.author_id = b.author_id;

-- C3. Total revenue (quantity * price) per genre, sorted descending.
SELECT b.genre,
       SUM(s.quantity * b.price) AS total_revenue
FROM sales s
JOIN books b ON s.book_id = b.book_id
GROUP BY b.genre
ORDER BY total_revenue DESC;

-- C4. Single city that generated the most revenue.
SELECT s.city,
       SUM(s.quantity * b.price) AS total_revenue
FROM sales s
JOIN books b ON s.book_id = b.book_id
GROUP BY s.city
ORDER BY total_revenue DESC
LIMIT 1;


-- ---- C2 - Extended Joins ----

-- C5. RIGHT JOIN from authors to books (every book + its author).
SELECT a.name AS author_name, b.title
FROM authors a
RIGHT JOIN books b ON a.author_id = b.author_id;
-- Why the row count matches INNER JOIN here:
-- Every book has a valid (non-NULL) author_id thanks to the FK
-- constraint, so every row on the "right" side (books) always finds
-- exactly one matching author. No right-table row is ever left
-- unmatched, so RIGHT JOIN produces the same 25 rows as INNER JOIN.

-- C6. FULL OUTER JOIN via the UNION trick (MySQL has no FULL OUTER JOIN).
SELECT a.name AS author_name, b.title
FROM authors a
LEFT JOIN books b ON a.author_id = b.author_id
UNION
SELECT a.name AS author_name, b.title
FROM authors a
RIGHT JOIN books b ON a.author_id = b.author_id;

-- C7. SELF JOIN: every mentored author alongside their mentor's name.
SELECT a.name AS mentored_author, m.name AS mentor
FROM authors a
JOIN authors m ON a.mentor_id = m.author_id;


-- ---- C3 - Set Operations ----

-- C8. CROSS JOIN: every combination of city and customer_type.
SELECT c.city, t.customer_type
FROM (SELECT DISTINCT city FROM sales) c
CROSS JOIN (SELECT DISTINCT customer_type FROM sales) t;

-- C9. UNION: all Indian authors + all authors born after 1970 (deduped).
SELECT name FROM authors WHERE country = 'India'
UNION
SELECT name FROM authors WHERE born_year > 1970;

-- C10. Anti-join (LEFT JOIN + IS NULL): books that have never been sold.
-- Confirmed output: 15 rows (matches the 15-books-never-sold fact used
-- in B6) - e.g. One Indian Girl, 400 Days, Rain in the Mountains,
-- Landour Days, and all 3 Preeti Shenoy/Devdutt Pattanaik-adjacent
-- titles that never appear in the sales table.
SELECT b.*
FROM books b
LEFT JOIN sales s ON b.book_id = s.book_id
WHERE s.sale_id IS NULL;


-- ---- C4 - Subqueries ----

-- C11. Scalar subquery: books priced above the overall average price.
SELECT *
FROM books
WHERE price > (SELECT AVG(price) FROM books);

-- C12. IN subquery: sales of books in genre 'History' or 'Mythology'.
SELECT s.*
FROM sales s
WHERE s.book_id IN (
    SELECT book_id FROM books WHERE genre IN ('History', 'Mythology')
);

-- C13. > ALL: books priced higher than every single Fiction book.
SELECT *
FROM books
WHERE price > ALL (
    SELECT price FROM books WHERE genre = 'Fiction'
);

-- C14. Correlated subquery: books priced above their own genre's average.
SELECT b1.*
FROM books b1
WHERE b1.price > (
    SELECT AVG(b2.price)
    FROM books b2
    WHERE b2.genre = b1.genre
);


-- ---- C5 - EXISTS / NOT EXISTS ----

-- C15. EXISTS: authors who have written at least one book after 2018.
SELECT a.*
FROM authors a
WHERE EXISTS (
    SELECT 1 FROM books b
    WHERE b.author_id = a.author_id
      AND b.published_year > 2018
);

-- C16. NOT EXISTS: authors who have never written a Business-genre book.
SELECT a.*
FROM authors a
WHERE NOT EXISTS (
    SELECT 1 FROM books b
    WHERE b.author_id = a.author_id
      AND b.genre = 'Business'
);

-- C17. IN subquery: all sales for books written by Indian authors.
SELECT s.*
FROM sales s
WHERE s.book_id IN (
    SELECT b.book_id
    FROM books b
    JOIN authors a ON b.author_id = a.author_id
    WHERE a.country = 'India'
);


-- ---- C6 - Window Functions ----

-- C18. Every book alongside its genre's average price (all 25 rows).
SELECT title, genre, price,
       AVG(price) OVER (PARTITION BY genre) AS genre_avg_price
FROM books;

-- C19. Top 2 highest-priced books in each genre (ROW_NUMBER).
SELECT title, genre, price, rn
FROM (
    SELECT title, genre, price,
           ROW_NUMBER() OVER (PARTITION BY genre ORDER BY price DESC) AS rn
    FROM books
) ranked
WHERE rn <= 2;

-- C20. LAG: each sale of book_id 115 (Atomic Habits) alongside the
--      quantity of the previous sale, sorted by sale_date. First sale
--      shows NULL for previous quantity (LAG's default behaviour).
SELECT sale_id, sale_date, quantity,
       LAG(quantity) OVER (ORDER BY sale_date) AS prev_quantity
FROM sales
WHERE book_id = 115
ORDER BY sale_date;
-- Confirmed output (8 rows, first prev_quantity is NULL):
-- 1003 2024-01-22  5  NULL
-- 1006 2024-02-02  3  5
-- 1011 2024-02-22  6  3
-- 1017 2024-03-18  2  6
-- 1022 2024-04-05  3  2
-- 1028 2024-05-01  5  3
-- 1035 2024-06-02  4  5
-- 1039 2024-06-18  2  4

-- C21. Running total of quantity across all sales, ordered by sale_date.
SELECT sale_id, sale_date, quantity,
       SUM(quantity) OVER (ORDER BY sale_date) AS running_total
FROM sales
ORDER BY sale_date;


-- ---- C7 - CTEs & Synthesis ----

-- C22. CTE version: total quantity sold per book, joined to book details.
WITH book_totals AS (
    SELECT book_id, SUM(quantity) AS total_qty
    FROM sales
    GROUP BY book_id
)
SELECT b.title, bt.total_qty
FROM book_totals bt
JOIN books b ON b.book_id = bt.book_id;

-- C23. Multi-CTE: revenue per genre, then rank genres by revenue.
WITH genre_revenue AS (
    SELECT b.genre,
           SUM(s.quantity * b.price) AS revenue
    FROM sales s
    JOIN books b ON s.book_id = b.book_id
    GROUP BY b.genre
),
ranked_genres AS (
    SELECT genre, revenue,
           RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
    FROM genre_revenue
)
SELECT genre, revenue, revenue_rank
FROM ranked_genres
ORDER BY revenue_rank;

-- C24. Comprehensive: per genre - top-selling book, its author, its
--      total quantity sold, and the genre's total revenue. Sorted by
--      genre revenue descending.
WITH book_sales AS (
    SELECT b.book_id, b.title, b.genre, b.author_id, b.price,
           SUM(s.quantity) AS total_qty
    FROM sales s
    JOIN books b ON s.book_id = b.book_id
    GROUP BY b.book_id, b.title, b.genre, b.author_id, b.price
),
genre_revenue AS (
    SELECT genre, SUM(total_qty * price) AS genre_revenue
    FROM book_sales
    GROUP BY genre
),
ranked_books AS (
    SELECT bs.*,
           ROW_NUMBER() OVER (PARTITION BY bs.genre ORDER BY bs.total_qty DESC) AS rn
    FROM book_sales bs
)
SELECT rb.genre,
       rb.title      AS top_selling_book,
       a.name        AS author_name,
       rb.total_qty,
       gr.genre_revenue
FROM ranked_books rb
JOIN authors a       ON a.author_id = rb.author_id
JOIN genre_revenue gr ON gr.genre = rb.genre
WHERE rb.rn = 1
ORDER BY gr.genre_revenue DESC;
-- Confirmed output (5 rows, one per genre that has sales):
-- Self-Help  Atomic Habits         James Clear        30  10470.00
-- Business   Rich Dad Poor Dad     Robert Kiyosaki    13   8826.00
-- Mythology  Immortals of Meluha   Amish Tripathi     12   8477.00
-- History    Sapiens               Yuval Harari       13   6487.00
-- Fiction    The Silent Patient    Alex Michaelides   10   4985.00
-- (Biography has no sales at all, so it doesn't appear here.)
