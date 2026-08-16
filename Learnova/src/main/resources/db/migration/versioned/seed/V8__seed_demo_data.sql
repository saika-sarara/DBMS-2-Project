-- =========================================================
-- V8: Demo seed data
--
-- The final demo state of the platform (what the old V3 seed +
-- V15 reseed produced):
--   * the three real Learnova accounts (password: password123)
--     -- Khadiza Sultana (ADMIN), Maliha Tasnim (STUDENT),
--     Saika Sarara (STUDENT). The bootstrap admin
--     (admin@learnova.com) is NOT seeded here; it is provisioned
--     at startup by AdminBootstrapRunner from BOOTSTRAP_ADMIN_*
--     environment variables.
--   * the six demo courses (the catalogue trigger from V5 keeps
--     slug / search_vector / published_at current as they land)
--   * the twelve demo lessons
--   * the Database Engineer track with its three courses
--
-- The students start with no enrollments. Sequence values are
-- re-aligned to MAX(id) afterwards so auto-generated rows never
-- collide with the explicitly-inserted ids.
-- =========================================================

-- =========================================================
-- 1. Demo accounts + roles
-- =========================================================

INSERT INTO public.users (email, password_hash, first_name, last_name, account_status)
VALUES
    ('sultanakhadiza37@gmail.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Khadiza', 'Sultana', 'ACTIVE'),
    ('malihatasnim@gmail.com',    '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Maliha', 'Tasnim', 'ACTIVE'),
    ('saikasarara@gmail.com',     '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Saika', 'Sarara', 'ACTIVE')
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name IN ('ADMIN', 'STUDENT')
WHERE (u.email, r.name) IN (
    ('sultanakhadiza37@gmail.com', 'ADMIN'),
    ('malihatasnim@gmail.com',    'STUDENT'),
    ('saikasarara@gmail.com',     'STUDENT')
)
ON CONFLICT DO NOTHING;

-- =========================================================
-- 2. Demo courses
--
-- category_id maps to the three catalogue categories seeded in V3
-- (Database=1, Programming=2, Data Science=3). instructor_id is
-- resolved to the new ADMIN account. difficulty / short_description
-- / ratings are demo values; slug and search_vector are generated
-- by trg_refresh_course_catalogue_fields.
-- =========================================================

INSERT INTO public.courses (
    id,
    title,
    status,
    description,
    short_description,
    category_id,
    difficulty,
    avg_rating,
    review_count,
    instructor_id
)
VALUES
    (
        1,
        'Database Design Fundamentals',
        'PUBLISHED',
        'Core concepts of relational database design: ER modeling and normalization.',
        'Core concepts of relational database design: ER modeling and normalization.',
        1,
        'BEGINNER',
        4.70,
        128,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    ),
    (
        2,
        'SQL & Query Optimization',
        'PUBLISHED',
        'Write efficient SQL and learn how indexes and query plans work.',
        'Write efficient SQL and learn how indexes and query plans work.',
        1,
        'INTERMEDIATE',
        4.50,
        96,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    ),
    (
        3,
        'Intro to Neo4j Graph Databases',
        'PUBLISHED',
        'Model connected data with graphs and query it with Cypher.',
        'Model connected data with graphs and query it with Cypher.',
        1,
        'INTERMEDIATE',
        4.30,
        54,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    ),
    (
        4,
        'Python for Data Science',
        'PUBLISHED',
        'Practical Python for data analysis with pandas and Jupyter.',
        'Practical Python for data analysis with pandas and Jupyter.',
        3,
        'BEGINNER',
        4.80,
        210,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    ),
    (
        5,
        'Modern React & TypeScript',
        'PENDING_REVIEW',
        'Build type-safe React applications with modern hooks and tooling.',
        'Build type-safe React applications with modern hooks and tooling.',
        2,
        'INTERMEDIATE',
        0.00,
        0,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    ),
    (
        6,
        'Data Warehousing & ETL',
        'DRAFT',
        'Design data warehouses and build ETL pipelines.',
        'Design data warehouses and build ETL pipelines.',
        1,
        'ADVANCED',
        0.00,
        0,
        (SELECT id FROM public.users WHERE email = 'sultanakhadiza37@gmail.com')
    );

-- =========================================================
-- 3. Demo lessons (flat lessons, no modules -- the syllabus
-- function renders them as the ungrouped module)
-- =========================================================

INSERT INTO public.lessons (course_id, title, sequence_order)
VALUES
    (1, 'Introduction to Databases', 1),
    (1, 'Entity-Relationship Modeling', 2),
    (1, 'First Normal Form', 3),
    (1, 'Normalizing to 3NF', 4),
    (2, 'SELECT and Joins', 1),
    (2, 'Subqueries and CTEs', 2),
    (2, 'Indexes', 3),
    (2, 'Reading Query Plans', 4),
    (3, 'Why Graph Databases', 1),
    (3, 'Cypher Basics', 2),
    (4, 'Python Intro', 1),
    (4, 'Pandas DataFrames', 2);

-- =========================================================
-- 4. Demo track
-- =========================================================

INSERT INTO public.tracks (id, title, status, description)
VALUES (1, 'Database Engineer', 'PUBLISHED', 'From schema design to query optimization and graph modeling.');

INSERT INTO public.track_courses (track_id, course_id, sequence_order)
VALUES (1, 1, 1), (1, 2, 2), (1, 3, 3);

-- =========================================================
-- 5. Re-align identity sequences after explicit-ID inserts
-- =========================================================

SELECT setval(
    pg_get_serial_sequence('public.users', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.users)
);

SELECT setval(
    pg_get_serial_sequence('public.categories', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.categories)
);

SELECT setval(
    pg_get_serial_sequence('public.courses', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.courses)
);

SELECT setval(
    pg_get_serial_sequence('public.lessons', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.lessons)
);

SELECT setval(
    pg_get_serial_sequence('public.tracks', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.tracks)
);
