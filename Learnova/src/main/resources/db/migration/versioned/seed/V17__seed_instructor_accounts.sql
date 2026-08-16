-- =========================================================
-- V17: Instructor demo accounts
--
-- V8 only seeded one ADMIN and two STUDENT accounts, and every
-- demo course was owned by the admin. This migration adds the
-- missing instructor layer so the instructor authoring + admin
-- moderation flows can be demoed end-to-end:
--
--   * two INSTRUCTOR accounts (password: password123, same
--     BCrypt hash as the V8 accounts)
--   * the six demo courses re-assigned to those instructors
--     (courses 1-3 -> Rafi Ahmed, courses 4-6 -> Nusrat Jahan)
--   * modules + lessons for courses 5 (pending) and 6 (draft)
--     so every course actually has teachable content
--   * a pending instructor request from the student Saika Sarara
--     so the admin moderation queue is not empty
--
-- Idempotent: users are keyed on email, role/ownership updates
-- only touch rows for the known demo emails.
-- =========================================================

-- =========================================================
-- 1. Instructor accounts
-- =========================================================

INSERT INTO public.users (email, password_hash, first_name, last_name, account_status)
VALUES
    ('rafiahmed@gmail.com',   '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Rafi',   'Ahmed', 'ACTIVE'),
    ('nusratjahan@gmail.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Nusrat', 'Jahan', 'ACTIVE')
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name = 'INSTRUCTOR'
WHERE u.email IN ('rafiahmed@gmail.com', 'nusratjahan@gmail.com')
ON CONFLICT DO NOTHING;

-- =========================================================
-- 2. Re-assign demo courses to the instructors
-- =========================================================

UPDATE public.courses
SET instructor_id = (SELECT id FROM public.users WHERE email = 'rafiahmed@gmail.com')
WHERE id IN (1, 2, 3);

UPDATE public.courses
SET instructor_id = (SELECT id FROM public.users WHERE email = 'nusratjahan@gmail.com')
WHERE id IN (4, 5, 6);

-- =========================================================
-- 3. Content for the pending + draft courses
--
-- Courses 1-4 keep the flat lessons from V8. Courses 5 and 6
-- get a module each so a pending course has real content and the
-- draft course can be edited/submitted from the instructor editor.
-- =========================================================

INSERT INTO public.modules (course_id, title, description, sequence_order)
VALUES
    (5, 'React Foundations', 'Components, props, state and hooks.', 1),
    (6, 'Data Warehousing Basics', 'Designing star schemas and ETL flows.', 1);

INSERT INTO public.lessons (course_id, module_id, title, sequence_order)
VALUES
    (5, (SELECT id FROM public.modules WHERE course_id = 5 AND sequence_order = 1), 'Components & Props', 1),
    (5, (SELECT id FROM public.modules WHERE course_id = 5 AND sequence_order = 1), 'State & Hooks', 2),
    (6, (SELECT id FROM public.modules WHERE course_id = 6 AND sequence_order = 1), 'Star Schemas', 1);

-- =========================================================
-- 4. Pending instructor request (from the student Saika Sarara)
-- =========================================================

INSERT INTO public.instructor_requests (user_id, status, request_message)
SELECT id, 'PENDING', 'I want to teach Data Science and machine learning foundations.'
FROM public.users
WHERE email = 'saikasarara@gmail.com'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 5. Re-align identity sequences after explicit-ID inserts
-- =========================================================

SELECT setval(
    pg_get_serial_sequence('public.users', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.users)
);

SELECT setval(
    pg_get_serial_sequence('public.courses', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.courses)
);

SELECT setval(
    pg_get_serial_sequence('public.modules', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.modules)
);

SELECT setval(
    pg_get_serial_sequence('public.lessons', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.lessons)
);

SELECT setval(
    pg_get_serial_sequence('public.instructor_requests', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.instructor_requests)
);
