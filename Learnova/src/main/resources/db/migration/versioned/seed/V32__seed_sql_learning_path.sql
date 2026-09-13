-- Replace the old demo catalogue. Child learning data cascades from courses.
DELETE FROM public.certificates;
DELETE FROM public.notifications;
DELETE FROM public.tracks;
DELETE FROM public.courses;

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name = 'INSTRUCTOR'
WHERE u.email = 'saikasarara@gmail.com'
ON CONFLICT DO NOTHING;

UPDATE public.instructor_requests ir
SET status = 'APPROVED',
    reviewed_at = COALESCE(ir.reviewed_at, CURRENT_TIMESTAMP)
FROM public.users u
WHERE ir.user_id = u.id
  AND u.email = 'saikasarara@gmail.com'
  AND ir.status = 'PENDING';

INSERT INTO public.categories (name, slug, description)
VALUES ('Database Systems', 'database-systems', 'Relational data modeling, SQL, and database performance.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.courses (
    title, status, description, short_description, category_id, slug,
    difficulty, avg_rating, review_count, instructor_id, published_at
)
SELECT
    d.title, 'PUBLISHED', d.description, d.short_description, cat.id, d.slug,
    d.difficulty, d.avg_rating, d.review_count, instructor.id,
    CURRENT_TIMESTAMP - d.published_offset
FROM (VALUES
    ('Basic SQL', 'Learn relational database vocabulary and write SELECT queries with filters, sorting, joins, and aggregates.', 'Build confidence with everyday SQL queries.', 'basic-sql', 'BEGINNER', 4.70::NUMERIC, 128, INTERVAL '21 days'),
    ('Intermediate SQL', 'Use grouping, subqueries, common table expressions, window functions, and transactions to solve richer problems.', 'Write clear, composable SQL for real data tasks.', 'intermediate-sql', 'INTERMEDIATE', 4.60::NUMERIC, 84, INTERVAL '14 days'),
    ('Advanced SQL', 'Read query plans, design indexes, apply advanced joins and windows, and tune SQL for reliable production performance.', 'Optimize SQL and reason about database performance.', 'advanced-sql', 'ADVANCED', 4.80::NUMERIC, 51, INTERVAL '7 days')
) AS d(title, description, short_description, slug, difficulty, avg_rating, review_count, published_offset)
JOIN public.categories cat ON cat.slug = 'database-systems'
JOIN public.users instructor ON instructor.email = 'saikasarara@gmail.com'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.modules (course_id, title, description, sequence_order)
SELECT c.id, 'SQL Learning Module', 'A focused sequence of concepts and practice for this level.', 1
FROM public.courses c
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
ON CONFLICT (course_id, sequence_order) DO NOTHING;

INSERT INTO public.lessons (
    course_id, module_id, title, description, sequence_order,
    estimated_duration_minutes, is_preview
)
SELECT c.id, m.id, lesson.title, lesson.description, lesson.sequence_order,
       lesson.duration_minutes, lesson.is_preview
FROM (VALUES
    ('basic-sql', 'Introduction to Relational Data', 'Tables, rows, columns, primary keys, and the role of SQL.', 1, 20, TRUE),
    ('basic-sql', 'SELECT, WHERE, and ORDER BY', 'Read data, filter rows, and sort result sets.', 2, 25, FALSE),
    ('basic-sql', 'Joins and Aggregates', 'Combine tables and summarize results with COUNT, SUM, and AVG.', 3, 30, FALSE),
    ('intermediate-sql', 'Grouping and Subqueries', 'Use GROUP BY, HAVING, and nested queries to answer business questions.', 1, 25, TRUE),
    ('intermediate-sql', 'CTEs and Window Functions', 'Build readable multi-step queries and analytical calculations.', 2, 30, FALSE),
    ('intermediate-sql', 'Transactions and Data Integrity', 'Use transactions, constraints, and isolation concepts safely.', 3, 25, FALSE),
    ('advanced-sql', 'Query Plans and Indexes', 'Interpret EXPLAIN output and choose effective indexes.', 1, 30, TRUE),
    ('advanced-sql', 'Advanced Joins and Window Frames', 'Apply precise joins, ranking, and running calculations.', 2, 30, FALSE),
    ('advanced-sql', 'Functions and Performance Tuning', 'Package reusable logic and measure SQL performance improvements.', 3, 30, FALSE)
) AS lesson(course_slug, title, description, sequence_order, duration_minutes, is_preview)
JOIN public.courses c ON c.slug = lesson.course_slug
JOIN public.modules m ON m.course_id = c.id AND m.sequence_order = 1
ON CONFLICT (module_id, sequence_order) DO NOTHING;

INSERT INTO public.lesson_content_blocks (lesson_id, block_type, title, body_markdown, sequence_order)
SELECT l.id, 'markdown', l.title,
       'This lesson is part of the **' || c.title || '** learning path. Complete the lesson, then pass its quiz to unlock the next step.',
       1
FROM public.lessons l
JOIN public.courses c ON c.id = l.course_id
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
ON CONFLICT (lesson_id, sequence_order) DO NOTHING;

-- One active, five-question attempt quiz per course, attached to lesson 3.
INSERT INTO public.quizzes (
    lesson_id, course_id, title, passing_score, questions_per_attempt,
    daily_attempt_limit, quiz_type, is_active
)
SELECT l.id, c.id, c.title || ' Checkpoint Quiz', 60.00, 5, 3, 'LESSON', TRUE
FROM public.courses c
JOIN public.lessons l ON l.course_id = c.id AND l.sequence_order = 3
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
ON CONFLICT (lesson_id) DO NOTHING;

-- The instructor bank holds exactly twenty questions for every checkpoint.
INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
SELECT q.id,
       format('%s checkpoint question %s: Which practice most improves SQL query reliability?', c.title, n.question_number),
       n.question_number
FROM public.quizzes q
JOIN public.courses c ON c.id = q.course_id
CROSS JOIN generate_series(1, 20) AS n(question_number)
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
  AND q.quiz_type = 'LESSON'
  AND NOT EXISTS (
      SELECT 1 FROM public.quiz_questions existing
      WHERE existing.quiz_id = q.id
        AND existing.sequence_order = n.question_number
  );

INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
SELECT qq.id, option_data.option_label, option_data.option_text, option_data.is_correct
FROM public.quiz_questions qq
JOIN public.quizzes q ON q.id = qq.quiz_id
JOIN public.courses c ON c.id = q.course_id
CROSS JOIN LATERAL (VALUES
    ('A', 'Use explicit columns, parameterized values, and verify results.', TRUE),
    ('B', 'Rely on the physical row order returned by the database.', FALSE),
    ('C', 'Skip constraints and validate data only in the user interface.', FALSE),
    ('D', 'Run untested write statements directly against production data.', FALSE)
) AS option_data(option_label, option_text, is_correct)
WHERE c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
  AND q.quiz_type = 'LESSON'
ON CONFLICT (question_id, option_label) DO NOTHING;