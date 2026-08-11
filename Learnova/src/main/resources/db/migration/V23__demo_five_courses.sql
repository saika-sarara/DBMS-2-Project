-- =========================================================
-- V23: Add five demo courses with lesson content and quizzes
--
-- Inserts five additional demo courses, each with a "Getting Started"
-- module, three lessons (first lesson has a markdown content block),
-- and a short 5-question multiple-choice quiz attached to the first lesson.
-- Idempotent: guarded with ON CONFLICT / EXISTS checks so re-running
-- the migration is safe.
-- =========================================================

WITH chosen_instructor AS (
    SELECT u.id
    FROM public.users u
    WHERE EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = u.id
          AND r.name IN ('INSTRUCTOR', 'ADMIN')
    )
    ORDER BY
        CASE WHEN EXISTS (
            SELECT 1
            FROM public.user_roles ur
            JOIN public.roles r ON r.id = ur.role_id
            WHERE ur.user_id = u.id
              AND r.name = 'INSTRUCTOR'
        ) THEN 0 ELSE 1 END,
        u.id ASC
    LIMIT 1
)
INSERT INTO public.courses (title, status, description, short_description, category_id, slug, difficulty, avg_rating, review_count, instructor_id, published_at)
SELECT d.title, d.status, d.description, d.short_description, cat.id, d.slug, d.difficulty, d.avg_rating, d.review_count, ci.id, CURRENT_TIMESTAMP
FROM (VALUES
    ('Intro to Algorithms', 'PUBLISHED', 'Fundamental algorithms and problem-solving techniques: sorting, searching and basic algorithm analysis.', 'Learn basic algorithms and how to reason about them.', 'data-structures', 'intro-to-algorithms', 'INTERMEDIATE', 4.6, 42),
    ('Linux Command Line Basics', 'PUBLISHED', 'Navigate the Linux shell, manage files and processes, and use common command-line tools.', 'Get comfortable with the terminal and command-line utilities.', 'career-tracks', 'linux-command-line-basics', 'BEGINNER', 4.5, 33),
    ('REST API Testing with Postman', 'PUBLISHED', 'Use Postman to design, test and automate REST API requests and assertions.', 'Hands-on API testing workflows with Postman.', 'backend-development', 'rest-api-testing-postman', 'BEGINNER', 4.4, 18),
    ('Docker Fundamentals', 'PUBLISHED', 'Containerize applications with Docker, images, containers and basic orchestration patterns.', 'Learn the essentials of Docker and container workflows.', 'backend-development', 'docker-fundamentals', 'BEGINNER', 4.7, 29),
    ('Unit Testing in Java', 'PUBLISHED', 'Write unit tests with JUnit and structure testable Java code.', 'Introduction to unit testing patterns and JUnit basics.', 'backend-development', 'unit-testing-java', 'INTERMEDIATE', 4.5, 21)
) AS d(title, status, description, short_description, category_slug, slug, difficulty, avg_rating, review_count)
JOIN public.categories cat ON cat.slug = d.category_slug
CROSS JOIN chosen_instructor ci
ON CONFLICT (slug) DO NOTHING;

-- Modules: one "Getting Started" module per course
INSERT INTO public.modules (course_id, title, description, sequence_order)
SELECT c.id, 'Getting Started', 'The foundational concepts of this course.', 1
FROM public.courses c
WHERE c.slug IN ('intro-to-algorithms','linux-command-line-basics','rest-api-testing-postman','docker-fundamentals','unit-testing-java')
ON CONFLICT (course_id, sequence_order) DO NOTHING;

-- Lessons: three lessons per course
INSERT INTO public.lessons (course_id, module_id, title, sequence_order, estimated_duration_minutes, is_preview)
SELECT c.id, m.id, l.title, l.sequence_order, l.estimated_duration_minutes, l.is_preview
FROM (VALUES
    ('intro-to-algorithms', 'Introduction & Complexity', 1, 25, TRUE),
    ('intro-to-algorithms', 'Sorting and Searching', 2, 30, FALSE),
    ('intro-to-algorithms', 'Basic Graph Traversals', 3, 30, FALSE),

    ('linux-command-line-basics', 'Introduction to the Shell', 1, 20, TRUE),
    ('linux-command-line-basics', 'File and Process Management', 2, 25, FALSE),
    ('linux-command-line-basics', 'Pipes, Redirection and Tools', 3, 30, FALSE),

    ('rest-api-testing-postman', 'What is an API and HTTP Basics', 1, 20, TRUE),
    ('rest-api-testing-postman', 'Using Postman Collections', 2, 25, FALSE),
    ('rest-api-testing-postman', 'Writing Tests and Automating', 3, 30, FALSE),

    ('docker-fundamentals', 'Containers and Images', 1, 20, TRUE),
    ('docker-fundamentals', 'Building Dockerfiles', 2, 25, FALSE),
    ('docker-fundamentals', 'Running and Networking Containers', 3, 30, FALSE),

    ('unit-testing-java', 'Why Unit Test?', 1, 20, TRUE),
    ('unit-testing-java', 'JUnit Basics', 2, 25, FALSE),
    ('unit-testing-java', 'Mocking and Test Design', 3, 30, FALSE)
) AS l(course_slug, title, sequence_order, estimated_duration_minutes, is_preview)
JOIN public.courses c ON c.slug = l.course_slug
JOIN public.modules m ON m.course_id = c.id AND m.sequence_order = 1
ON CONFLICT (module_id, sequence_order) DO NOTHING;

-- Lesson content blocks (markdown) for lesson 1 of each course
INSERT INTO public.lesson_content_blocks (lesson_id, block_type, title, body_markdown, sequence_order)
SELECT l.id, 'markdown', l.title, cb.body, 1
FROM (VALUES
    ('intro-to-algorithms', 'Introduction & Complexity', 'Algorithms are step-by-step procedures to solve problems. Use Big-O notation to describe time and space complexity.'),
    ('linux-command-line-basics', 'Introduction to the Shell', 'The shell interprets commands. Learn cd, ls, cat, grep and common navigation and file manipulation patterns.'),
    ('rest-api-testing-postman', 'What is an API and HTTP Basics', 'APIs let clients interact with servers. Learn HTTP verbs, status codes and request/response structure.'),
    ('docker-fundamentals', 'Containers and Images', 'Containers package code and dependencies. Images are immutable snapshots used to run containers.'),
    ('unit-testing-java', 'Why Unit Test?', 'Unit tests verify small units of behaviour. JUnit provides annotations, assertions and lifecycle hooks to structure tests.')
) AS cb(course_slug, lesson_title, body)
JOIN public.lessons l ON l.title = cb.lesson_title
JOIN public.courses c ON c.id = l.course_id AND c.slug = cb.course_slug
ON CONFLICT (lesson_id, sequence_order) DO NOTHING;

-- Quizzes: one quiz attached to lesson 1 of each course, with 5 questions and options
DO $$
DECLARE
    rec RECORD;
    v_q RECORD;
    v_quiz_id BIGINT;
BEGIN
    FOR rec IN SELECT c.slug AS course_slug, l.id AS lesson_id, l.title AS lesson_title
               FROM public.courses c
               JOIN public.modules m ON m.course_id = c.id AND m.sequence_order = 1
               JOIN public.lessons l ON l.module_id = m.id AND l.sequence_order = 1
               WHERE c.slug IN ('intro-to-algorithms','linux-command-line-basics','rest-api-testing-postman','docker-fundamentals','unit-testing-java')
    LOOP
        -- Create quiz if missing
        INSERT INTO public.quizzes (lesson_id, title, passing_score, questions_per_attempt, daily_attempt_limit)
        VALUES (rec.lesson_id, rec.lesson_title || ' — Quick Quiz', 60.00, 5, 3)
        ON CONFLICT (lesson_id) DO NOTHING;

        -- Obtain quiz id (existing or newly inserted)
        SELECT q.id INTO v_quiz_id FROM public.quizzes q WHERE q.lesson_id = rec.lesson_id LIMIT 1;

        -- Insert 5 questions if they don't already exist (identified by sequence_order)
        IF NOT EXISTS (SELECT 1 FROM public.quiz_questions qq WHERE qq.quiz_id = v_quiz_id AND qq.sequence_order = 1) THEN
            INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
            VALUES
                (v_quiz_id, 'What is the focus of this lesson?', 1),
                (v_quiz_id, 'Which statement is true about the topic covered?', 2),
                (v_quiz_id, 'Which tool/construct is commonly used in this area?', 3),
                (v_quiz_id, 'Which of the following is a best practice?', 4),
                (v_quiz_id, 'What is a common failure mode to avoid?', 5);
        END IF;

        -- Insert options for each question if missing. Use labels A-D with one correct per question.
        -- For simplicity we mark option A as correct for question 1, B for question 2, etc.
        -- The actual correctness distribution is not critical for demo purposes.
        PERFORM 1; -- nop to satisfy PL/pgSQL

        -- Loop through inserted questions and add options if not present
        FOR v_q IN SELECT id, sequence_order FROM public.quiz_questions WHERE quiz_id = v_quiz_id
        LOOP
            IF NOT EXISTS (SELECT 1 FROM public.quiz_options qo WHERE qo.question_id = v_q.id) THEN
                INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
                VALUES
                    (v_q.id, 'A', 'Option A (demo)', CASE WHEN v_q.sequence_order = 1 THEN TRUE ELSE FALSE END),
                    (v_q.id, 'B', 'Option B (demo)', CASE WHEN v_q.sequence_order = 2 THEN TRUE ELSE FALSE END),
                    (v_q.id, 'C', 'Option C (demo)', CASE WHEN v_q.sequence_order = 3 THEN TRUE ELSE FALSE END),
                    (v_q.id, 'D', 'Option D (demo)', CASE WHEN v_q.sequence_order = 4 THEN TRUE ELSE FALSE END);
                -- If none of the CASE produced TRUE (question 5), mark 'D' as correct by updating
                UPDATE public.quiz_options qo
                SET is_correct = TRUE
                WHERE qo.id IN (
                    SELECT id FROM public.quiz_options WHERE question_id = v_q.id AND is_correct = TRUE
                )
                ;
                -- Ensure at least one correct option; if none, set D as correct
                IF NOT EXISTS (SELECT 1 FROM public.quiz_options WHERE question_id = v_q.id AND is_correct) THEN
                    UPDATE public.quiz_options SET is_correct = TRUE WHERE question_id = v_q.id AND option_label = 'D';
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Re-align sequences
SELECT setval(pg_get_serial_sequence('public.courses', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.courses));
SELECT setval(pg_get_serial_sequence('public.modules', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.modules));
SELECT setval(pg_get_serial_sequence('public.lessons', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.lessons));
SELECT setval(pg_get_serial_sequence('public.lesson_content_blocks', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.lesson_content_blocks));
SELECT setval(pg_get_serial_sequence('public.quizzes', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.quizzes));
SELECT setval(pg_get_serial_sequence('public.quiz_questions', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.quiz_questions));
SELECT setval(pg_get_serial_sequence('public.quiz_options', 'id'), (SELECT COALESCE(MAX(id), 1) FROM public.quiz_options));

-- End of migration
