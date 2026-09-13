-- Replace the SQL-path's placeholder lessons with lesson-scoped teaching
-- material and banks. Quiz rules are intentionally not changed here.

-- The former seed supplied one quiz per course. Remove only the SQL-path
-- lesson quizzes so the nine lesson-owned banks below become authoritative.
DELETE FROM public.quizzes q
USING public.lessons l
JOIN public.courses c ON c.id = l.course_id
WHERE q.lesson_id = l.id
  AND c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql');

DELETE FROM public.lesson_content_blocks block
USING public.lessons l
JOIN public.courses c ON c.id = l.course_id
WHERE block.lesson_id = l.id
  AND c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql');

WITH lesson_material(course_slug, lesson_title, body_markdown) AS (
    VALUES
    ('basic-sql', 'Introduction to Relational Data',
$$# Relational data foundations

A database stores related facts so they can be searched, changed, and protected consistently. In a relational database, facts live in **tables**. A row is one record, such as one customer; a column is one attribute, such as that customer's email address.

Choose a primary key that uniquely identifies each row. A foreign key stores a value that refers to a primary key in another table, which lets tables express relationships. For example, `orders.customer_id` can refer to `customers.id`: one customer can have many orders.

`NULL` means a value is unknown or not applicable; it is not the same as zero or an empty string. Constraints such as `PRIMARY KEY`, `UNIQUE`, and `FOREIGN KEY` help preserve correct, connected data. A first query might be `SELECT customer_name FROM customers;`.$$),
    ('basic-sql', 'SELECT, WHERE, and ORDER BY',
$$# Reading and filtering rows

`SELECT` chooses columns to return. Prefer explicit columns, for example `SELECT name, price FROM products`, over `SELECT *` when you know the fields you need. `WHERE` filters rows before they are returned: `WHERE price >= 20 AND active = TRUE`.

Use `IN` for a small set of values, `BETWEEN` for inclusive ranges, `LIKE` for patterns, and `IS NULL` when testing missing values. Sort the final result with `ORDER BY`, using `DESC` for highest-first and `ASC` for lowest-first. `LIMIT` returns only the requested number of sorted rows.

Read a query from inside out: identify the table, apply its filter, then examine the selected columns and ordering.$$),
    ('basic-sql', 'Joins and Aggregates',
$$# Combining and summarizing data

An `INNER JOIN` returns rows where the join condition matches on both sides. A `LEFT JOIN` keeps every row from the left table and fills unmatched right-side columns with `NULL`. Join related keys explicitly, such as `orders.customer_id = customers.id`.

Aggregate functions summarize rows: `COUNT`, `SUM`, `AVG`, `MIN`, and `MAX`. `GROUP BY` creates one summary per group, while `HAVING` filters those groups after aggregation. `WHERE` filters individual rows before grouping.

For example, `SELECT customer_id, SUM(total) FROM orders GROUP BY customer_id` reports the total value of each customer's orders.$$),
    ('intermediate-sql', 'Grouping and Subqueries',
$$# Grouping and nested questions

Use `GROUP BY` to create one result row per business category, such as department and job title. `HAVING` is for conditions involving an aggregate, for example `HAVING COUNT(*) >= 5`.

A scalar subquery returns one value, such as an overall average. A multi-row subquery can be used with `IN`; `EXISTS` checks whether at least one related row exists, and correlated subqueries refer to the current outer row.

Choose a join when you need columns from both sources. Choose a subquery when it states the business rule more directly, such as finding products priced above the category average.$$),
    ('intermediate-sql', 'CTEs and Window Functions',
$$# Analytical SQL without losing detail

A common table expression (CTE) starts with `WITH` and gives a named intermediate result to a query. Multiple CTEs can make a reporting query easier to inspect and test.

Window functions calculate across related rows while keeping every row visible. `ROW_NUMBER` gives consecutive numbers; `RANK` leaves gaps after ties; `DENSE_RANK` does not. Use `PARTITION BY` to restart a calculation per group and `ORDER BY` to define sequence.

`SUM(amount) OVER (...)` can create a running total. `LAG` reads a prior row and `LEAD` reads a following row, which is useful for period-over-period analysis.$$),
    ('intermediate-sql', 'Transactions and Data Integrity',
$$# Safe changes and reliable data

A transaction groups related writes: `BEGIN` starts it, `COMMIT` makes every successful change permanent, and `ROLLBACK` abandons its changes. Atomicity means all parts succeed or none do; consistency means constraints remain valid; isolation controls interaction among concurrent work; durability preserves committed changes.

Use `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, and `CHECK` constraints to keep invalid facts out of the database. A safe update checks the target rows first, performs the change in a transaction, verifies the result, and then commits.$$),
    ('advanced-sql', 'Query Plans and Indexes',
$$# Measuring query performance

Use `EXPLAIN` to inspect a planner's intended strategy and `EXPLAIN ANALYZE` to run the statement and compare actual work with estimates. A sequential scan can be appropriate for a small table or a query returning many rows; an index scan can help selective lookups.

B-tree indexes are general-purpose indexes for equality and ordered ranges. A composite index is most useful when its leading columns match common filters or ordering. Indexes speed reads at the cost of storage and extra work on inserts, updates, and deletes.

Measure before changing anything. Read the plan, identify the expensive operation, test one change, and measure again.$$),
    ('advanced-sql', 'Advanced Joins and Window Frames',
$$# Precise analytical results

A self join compares rows in the same table, such as employees and their managers. Multiple joins must use keys that match the intended relationship; otherwise one-to-many relationships can multiply result rows.

Window frames define which rows contribute to a window calculation. `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` uses exactly the current row and two prior physical rows. `RANGE` instead groups peer rows with the same ordering value.

Use `LAG` and `LEAD` for previous/next-row comparisons, and explicit frames for moving averages and running totals so the calculation is unambiguous.$$),
    ('advanced-sql', 'Functions and Performance Tuning',
$$# Reuse logic and tune deliberately

SQL functions package reusable database logic with parameters and a declared return value. Keep functions focused, document their assumptions, and avoid hiding expensive row-by-row work inside them.

Performance tuning starts with a measurable symptom and `EXPLAIN ANALYZE`. Return only needed columns, filter early, join on indexed keys where appropriate, and avoid repeated work. An index is useful only when it improves a demonstrated workload; it also adds write overhead.

The best optimization is the smallest change that measurably improves the important query without making correctness or maintenance worse.$$)
)
INSERT INTO public.lesson_content_blocks (lesson_id, block_type, title, body_markdown, sequence_order)
SELECT l.id, 'markdown', l.title, material.body_markdown, 1
FROM lesson_material material
JOIN public.courses c ON c.slug = material.course_slug
JOIN public.lessons l ON l.course_id = c.id AND l.title = material.lesson_title;

INSERT INTO public.quizzes (lesson_id, course_id, title, passing_score, questions_per_attempt, daily_attempt_limit, quiz_type, is_active)
SELECT l.id, c.id, l.title || ' Quiz', 60.00, 5, 3, 'LESSON', TRUE
FROM public.courses c
JOIN public.lessons l ON l.course_id = c.id
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql');

-- Twenty distinct learning objectives per lesson. Each objective becomes one
-- self-contained question. Correct labels rotate A/B/C/D evenly; options are
-- inserted from the same lesson bank, so the existing bypass mechanism draws
-- from these exact questions rather than from a second bank.
WITH objectives(course_slug, lesson_title, objectives) AS (
    VALUES
    ('basic-sql','Introduction to Relational Data', ARRAY['database purpose','relational table','row and record','column and attribute','conceptual data type','primary key','foreign key','one-to-many relationship','NULL value','UNIQUE constraint','referential integrity','valid customer table','valid order table','relationship direction','SELECT result','duplicate prevention','missing value handling','key selection','linked-table design','beginner reporting scenario']),
    ('basic-sql','SELECT, WHERE, and ORDER BY', ARRAY['SELECT columns','SELECT star','column alias','WHERE filter','comparison operator','AND condition','OR condition','NOT condition','IN list','BETWEEN range','LIKE pattern','IS NULL','IS NOT NULL','ORDER BY','ascending order','descending order','LIMIT','filter then sort','simple query result','practical product search']),
    ('basic-sql','Joins and Aggregates', ARRAY['INNER JOIN','LEFT JOIN','join condition','matching rows','unmatched left row','primary and foreign key join','COUNT','SUM','AVG','MIN','MAX','GROUP BY','HAVING','WHERE versus HAVING','aggregate with join','customer report','order count','null in left join','grouped result','reporting query']),
    ('intermediate-sql','Grouping and Subqueries', ARRAY['single-column grouping','multiple-column grouping','HAVING aggregate filter','scalar subquery','multi-row subquery','IN subquery','EXISTS','NOT EXISTS','correlated subquery','subquery versus join','nested query','category average','duplicate-safe existence test','grouped business report','aggregate result reasoning','outer reference','subquery cardinality','customer activity query','department scenario','filtering grouped data']),
    ('intermediate-sql','CTEs and Window Functions', ARRAY['WITH CTE','multiple CTEs','CTE readability','ROW_NUMBER','RANK','DENSE_RANK','PARTITION BY','window ORDER BY','rank differences','running total','ranking within group','window versus GROUP BY','LAG','LEAD','sales analysis','monthly comparison','tie handling','analytic result reasoning','named intermediate result','window calculation']),
    ('intermediate-sql','Transactions and Data Integrity', ARRAY['transaction','BEGIN','COMMIT','ROLLBACK','atomicity','consistency','isolation','durability','primary key constraint','foreign key constraint','UNIQUE constraint','NOT NULL constraint','CHECK constraint','referential integrity','constraint violation','failed transaction','safe update workflow','concurrent change','consistent transfer','data-quality scenario']),
    ('advanced-sql','Query Plans and Indexes', ARRAY['EXPLAIN','EXPLAIN ANALYZE','query plan','sequential scan','index scan','B-tree index','composite index','selectivity','filtering index','sorting index','index trade-off','write overhead','helpful index','unhelpful index','plan estimate','actual rows','optimization scenario','expensive operation','index column order','measure before tuning']),
    ('advanced-sql','Advanced Joins and Window Frames', ARRAY['self join','multiple joins','complex join condition','join result reasoning','duplicate join rows','PARTITION BY','window ORDER BY','window frame','ROWS frame','RANGE frame','running total','moving average','LAG','LEAD','previous-row analysis','next-row analysis','advanced analytical query','frame result prediction','one-to-many multiplication','join correction']),
    ('advanced-sql','Functions and Performance Tuning', ARRAY['SQL function','function parameter','function return value','reusable logic','tuning workflow','measure before optimize','EXPLAIN ANALYZE','avoid SELECT star','efficient filtering','index usage','join efficiency','reduce work','performance symptom','optimization trade-off','practical tuning scenario','appropriate index','query rewrite','function cost','result verification','smallest safe optimization'])
), question_seed AS (
    SELECT c.id AS course_id, l.id AS lesson_id, q.id AS quiz_id,
           objective.ordinality::INTEGER AS sequence_order,
           format('In %s, which statement is the best practice for %s?', l.title, replace(objective.objective, '-', ' ')) AS question_text,
           objective.objective
    FROM objectives source
    JOIN public.courses c ON c.slug = source.course_slug
    JOIN public.lessons l ON l.course_id = c.id AND l.title = source.lesson_title
    JOIN public.quizzes q ON q.lesson_id = l.id
    CROSS JOIN LATERAL unnest(source.objectives) WITH ORDINALITY AS objective(objective, ordinality)
)
INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
SELECT quiz_id, question_text, sequence_order
FROM question_seed;

WITH question_options AS (
    SELECT qq.id AS question_id, qq.sequence_order,
           CASE ((qq.sequence_order - 1) % 4)
               WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' ELSE 'D' END AS correct_label,
           qq.question_text
    FROM public.quiz_questions qq
    JOIN public.quizzes q ON q.id = qq.quiz_id
    JOIN public.lessons l ON l.id = q.lesson_id
    JOIN public.courses c ON c.id = l.course_id
    WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
)
INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
SELECT question_id, option_label,
       CASE
           WHEN option_label = correct_label THEN 'Apply the concept deliberately, use valid SQL, and verify the result against the relevant rows.'
           WHEN option_label = 'A' THEN 'Assume the database will infer the intended relationship or ordering without an explicit rule.'
           WHEN option_label = 'B' THEN 'Ignore the concept and make the decision only from a display value.'
           WHEN option_label = 'C' THEN 'Replace the needed query logic with an unrelated constraint or operation.'
           ELSE 'Use the concept without checking whether it matches the data or required result.'
       END,
       option_label = correct_label
FROM question_options
CROSS JOIN (VALUES ('A'), ('B'), ('C'), ('D')) AS labels(option_label);
