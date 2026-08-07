-- =========================================================
-- V22: Demo catalogue seed
--
-- Expands the catalogue to a full demo state without touching
-- the seeded users or the bootstrap admin:
--   * renames / merges the existing three categories into the
--     five canonical ones (Database Systems, Backend
--     Development, Web Development, Data Structures, Career
--     Tracks)
--   * adds eight published courses (SQL Fundamentals, PostgreSQL
--     for Beginners, Database Design and ER Modeling, Java
--     Backend Basics, Spring Boot REST API, HTML CSS JavaScript
--     Basics, Data Structures Essentials, Advanced PostgreSQL
--     Functions)
--   * adds four lifecycle-status courses (one DRAFT, one
--     PENDING_REVIEW, one REJECTED, one ARCHIVED)
--   * gives every new course a module, lessons and lesson
--     content blocks
--   * adds a prerequisite graph across the new courses
--   * adds a second published track (Full-Stack Java Developer)
--     and enrolls the demo students, seeding lesson progress so
--     every card state (enrolled / continue / locked / completed)
--     is visible out of the box
--
-- Idempotent: every insert is keyed on a stable slug and guarded
-- with ON CONFLICT DO NOTHING; category renames are keyed on the
-- existing slug. New courses are owned by the first INSTRUCTOR
-- account (falling back to the first ADMIN); if neither exists
-- the inserts become no-ops.
-- =========================================================

-- =========================================================
-- 1. Categories (rename / merge into the five canonical ones)
-- =========================================================

UPDATE public.categories
SET name = 'Database Systems',
    slug = 'database-systems',
    description = 'Relational and NoSQL data modeling, SQL and query optimization.'
WHERE slug = 'database';

UPDATE public.categories
SET name = 'Backend Development',
    slug = 'backend-development',
    description = 'Server-side programming: Java, Python, REST APIs and application backends.'
WHERE slug = 'data-science';

UPDATE public.categories
SET name = 'Web Development',
    slug = 'web-development',
    description = 'Frontend and full-stack web technologies: HTML, CSS, JavaScript and modern frameworks.'
WHERE slug = 'programming';

INSERT INTO public.categories (name, slug, description)
VALUES
    ('Data Structures', 'data-structures', 'Algorithms and data structures for efficient problem solving.'),
    ('Career Tracks',   'career-tracks',   'Curated learning paths that take you from fundamentals to job-ready skills.')
ON CONFLICT (slug) DO NOTHING;

-- =========================================================
-- 2. New published courses
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
INSERT INTO public.courses (
    title,
    status,
    description,
    short_description,
    category_id,
    slug,
    difficulty,
    avg_rating,
    review_count,
    instructor_id,
    published_at
)
SELECT
    d.title,
    d.status,
    d.description,
    d.short_description,
    cat.id,
    d.slug,
    d.difficulty,
    d.avg_rating,
    d.review_count,
    ci.id,
    CURRENT_TIMESTAMP - d.published_offset
FROM (VALUES
    (
        'SQL Fundamentals',
        'PUBLISHED',
        'Write correct SQL from the ground up: SELECT, filtering, joins, aggregation and the data model behind relational databases.',
        'Learn the essentials of writing and reading SQL queries.',
        'database-systems',
        'sql-fundamentals',
        'BEGINNER',
        4.70,
        150,
        INTERVAL '55 days'
    ),
    (
        'PostgreSQL for Beginners',
        'PUBLISHED',
        'A hands-on introduction to PostgreSQL: installing, creating tables with constraints, and running CRUD operations.',
        'Get started with the PostgreSQL database server and SQL.',
        'database-systems',
        'postgresql-for-beginners',
        'BEGINNER',
        4.65,
        98,
        INTERVAL '48 days'
    ),
    (
        'Database Design and ER Modeling',
        'PUBLISHED',
        'Design clean relational schemas with entity-relationship modeling, keys, and normalization up to 3NF.',
        'Turn messy requirements into a well-normalized database design.',
        'database-systems',
        'database-design-and-er-modeling',
        'INTERMEDIATE',
        4.55,
        42,
        INTERVAL '40 days'
    ),
    (
        'Java Backend Basics',
        'PUBLISHED',
        'Learn Java for the backend: syntax, classes and objects, collections, streams and basic error handling.',
        'A practical Java foundation for server-side development.',
        'backend-development',
        'java-backend-basics',
        'BEGINNER',
        4.40,
        61,
        INTERVAL '33 days'
    ),
    (
        'Spring Boot REST API',
        'PUBLISHED',
        'Build production-style REST APIs with Spring Boot: controllers, services, repositories and request validation.',
        'Create your first REST API with Spring Boot.',
        'backend-development',
        'spring-boot-rest-api',
        'INTERMEDIATE',
        4.80,
        73,
        INTERVAL '26 days'
    ),
    (
        'HTML CSS JavaScript Basics',
        'PUBLISHED',
        'The frontend trio: semantic HTML, modern CSS layout, and the JavaScript fundamentals that power the web.',
        'Learn the core languages every web page is built from.',
        'web-development',
        'html-css-javascript-basics',
        'BEGINNER',
        4.60,
        205,
        INTERVAL '19 days'
    ),
    (
        'Data Structures Essentials',
        'PUBLISHED',
        'Arrays, linked lists, stacks, queues, trees and graphs, with the algorithms to navigate them.',
        'Understand the data structures behind every program.',
        'data-structures',
        'data-structures-essentials',
        'INTERMEDIATE',
        4.50,
        55,
        INTERVAL '12 days'
    ),
    (
        'Advanced PostgreSQL Functions',
        'PUBLISHED',
        'Dive into stored functions, triggers, window functions and full-text search on PostgreSQL.',
        'Take your PostgreSQL skills to the advanced level.',
        'database-systems',
        'advanced-postgresql-functions',
        'ADVANCED',
        4.90,
        37,
        INTERVAL '5 days'
    )
) AS d(title, status, description, short_description, category_slug, slug, difficulty, avg_rating, review_count, published_offset)
JOIN public.categories cat ON cat.slug = d.category_slug
CROSS JOIN chosen_instructor ci
ON CONFLICT (slug) DO NOTHING;

-- =========================================================
-- 3. Lifecycle-status courses (draft / pending / rejected / archived)
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
INSERT INTO public.courses (
    title,
    status,
    description,
    short_description,
    category_id,
    slug,
    difficulty,
    avg_rating,
    review_count,
    instructor_id,
    submitted_at,
    rejection_reason
)
SELECT
    d.title,
    d.status,
    d.description,
    d.short_description,
    cat.id,
    d.slug,
    d.difficulty,
    d.avg_rating,
    d.review_count,
    ci.id,
    d.submitted_at,
    d.rejection_reason
FROM (VALUES
    (
        'GraphQL API Design',
        'DRAFT',
        'Design type-safe GraphQL APIs: schemas, resolvers and client integration.',
        'A draft course on building GraphQL APIs.',
        'backend-development',
        'graphql-api-design',
        'INTERMEDIATE',
        0.00,
        0,
        NULL,
        NULL
    ),
    (
        'Data Analytics with Python',
        'PENDING_REVIEW',
        'Analyze real datasets with pandas, NumPy and visualization libraries.',
        'Practical data analytics using the Python ecosystem.',
        'backend-development',
        'data-analytics-with-python',
        'INTERMEDIATE',
        0.00,
        0,
        CURRENT_TIMESTAMP,
        NULL
    ),
    (
        'Distributed Systems Theory',
        'REJECTED',
        'Consistency, replication, consensus and the CAP theorem for modern systems.',
        'Foundations of distributed systems.',
        'backend-development',
        'distributed-systems-theory',
        'ADVANCED',
        0.00,
        0,
        CURRENT_TIMESTAMP - INTERVAL '7 days',
        'Demo rejection reason: the course outline needs more hands-on exercises and fewer lecture slides.'
    ),
    (
        'Flash Animation Basics',
        'ARCHIVED',
        'Legacy timeline-based animation and ActionScript fundamentals.',
        'A legacy course on Flash animation.',
        'web-development',
        'flash-animation-basics',
        'BEGINNER',
        0.00,
        0,
        NULL,
        NULL
    )
) AS d(title, status, description, short_description, category_slug, slug, difficulty, avg_rating, review_count, submitted_at, rejection_reason)
JOIN public.categories cat ON cat.slug = d.category_slug
CROSS JOIN chosen_instructor ci
ON CONFLICT (slug) DO NOTHING;

-- =========================================================
-- 4. Modules (one "Getting Started" module per new course)
-- =========================================================

INSERT INTO public.modules (course_id, title, description, sequence_order)
SELECT c.id, 'Getting Started', 'The foundational concepts of this course.', 1
FROM public.courses c
WHERE c.slug IN (
    'sql-fundamentals',
    'postgresql-for-beginners',
    'database-design-and-er-modeling',
    'java-backend-basics',
    'spring-boot-rest-api',
    'html-css-javascript-basics',
    'data-structures-essentials',
    'advanced-postgresql-functions',
    'graphql-api-design',
    'data-analytics-with-python',
    'distributed-systems-theory',
    'flash-animation-basics'
)
ON CONFLICT (course_id, sequence_order) DO NOTHING;

-- =========================================================
-- 5. Lessons (published courses)
-- =========================================================

INSERT INTO public.lessons (
    course_id,
    module_id,
    title,
    sequence_order,
    estimated_duration_minutes,
    is_preview
)
SELECT c.id, m.id, l.title, l.sequence_order, l.estimated_duration_minutes, l.is_preview
FROM (VALUES
    ('sql-fundamentals',        'What is a Relational Database?',   1, 15, TRUE),
    ('sql-fundamentals',        'SELECT, WHERE and ORDER BY',       2, 20, FALSE),
    ('sql-fundamentals',        'Joins and Aggregate Functions',    3, 25, FALSE),
    ('postgresql-for-beginners','Installing and Connecting',        1, 15, TRUE),
    ('postgresql-for-beginners','Creating Tables with Constraints', 2, 20, FALSE),
    ('postgresql-for-beginners','CRUD with PostgreSQL',             3, 20, FALSE),
    ('database-design-and-er-modeling', 'Entities and Attributes',  1, 20, TRUE),
    ('database-design-and-er-modeling', 'Keys and Relationships',   2, 25, FALSE),
    ('database-design-and-er-modeling', 'Normalization to 3NF',     3, 30, FALSE),
    ('java-backend-basics',     'Java Syntax and Setup',            1, 20, TRUE),
    ('java-backend-basics',     'Classes, Objects and Inheritance', 2, 25, FALSE),
    ('java-backend-basics',     'Collections and Streams',          3, 25, FALSE),
    ('spring-boot-rest-api',    'Bootstrapping a Spring Boot App',  1, 20, TRUE),
    ('spring-boot-rest-api',    'Building a REST Controller',       2, 25, FALSE),
    ('spring-boot-rest-api',    'Persistence with Spring Data JPA', 3, 30, FALSE),
    ('html-css-javascript-basics', 'Semantic HTML',                 1, 15, TRUE),
    ('html-css-javascript-basics', 'Styling with Modern CSS',       2, 20, FALSE),
    ('html-css-javascript-basics', 'JavaScript Fundamentals',       3, 25, FALSE),
    ('data-structures-essentials', 'Arrays and Strings',            1, 20, TRUE),
    ('data-structures-essentials', 'Linked Lists, Stacks and Queues', 2, 30, FALSE),
    ('data-structures-essentials', 'Trees and Graphs',              3, 35, FALSE),
    ('advanced-postgresql-functions', 'Stored Functions and Triggers', 1, 30, TRUE),
    ('advanced-postgresql-functions', 'Window Functions',           2, 35, FALSE),
    ('advanced-postgresql-functions', 'Full-Text Search and JSON',  3, 35, FALSE)
) AS l(course_slug, title, sequence_order, estimated_duration_minutes, is_preview)
JOIN public.courses c ON c.slug = l.course_slug
JOIN public.modules m ON m.course_id = c.id AND m.sequence_order = 1
ON CONFLICT (module_id, sequence_order) DO NOTHING;

-- =========================================================
-- 6. Lessons (lifecycle courses)
-- =========================================================

INSERT INTO public.lessons (
    course_id,
    module_id,
    title,
    sequence_order,
    estimated_duration_minutes,
    is_preview
)
SELECT c.id, m.id, l.title, l.sequence_order, l.estimated_duration_minutes, l.is_preview
FROM (VALUES
    ('graphql-api-design',         'Schemas and Types',       1, 25, TRUE),
    ('graphql-api-design',         'Resolvers and Mutations', 2, 30, FALSE),
    ('data-analytics-with-python', 'pandas DataFrames',       1, 25, TRUE),
    ('data-analytics-with-python', 'Aggregation and Plots',   2, 30, FALSE),
    ('distributed-systems-theory', 'Consistency Models',      1, 30, TRUE),
    ('distributed-systems-theory', 'Raft Consensus',          2, 40, FALSE),
    ('flash-animation-basics',     'Timeline and Tweening',   1, 20, TRUE),
    ('flash-animation-basics',     'ActionScript Basics',     2, 25, FALSE)
) AS l(course_slug, title, sequence_order, estimated_duration_minutes, is_preview)
JOIN public.courses c ON c.slug = l.course_slug
JOIN public.modules m ON m.course_id = c.id AND m.sequence_order = 1
ON CONFLICT (module_id, sequence_order) DO NOTHING;

-- =========================================================
-- 7. Lesson content blocks (markdown)
-- =========================================================

INSERT INTO public.lesson_content_blocks (
    lesson_id,
    block_type,
    title,
    body_markdown,
    sequence_order
)
SELECT l.id, 'markdown', l.title, cb.body, 1
FROM (VALUES
    ('sql-fundamentals',        'What is a Relational Database?',   'A relational database stores data in tables made of rows and columns. Tables relate to each other through keys, which lets you model real-world entities without duplicating data.\n\n- Tables have a fixed column structure\n- Rows are individual records\n- Primary and foreign keys connect tables'),
    ('sql-fundamentals',        'SELECT, WHERE and ORDER BY',       'The SELECT statement reads data. Use WHERE to filter rows and ORDER BY to sort the result set.\n\n```sql\nSELECT title FROM courses\nWHERE difficulty = ''BEGINNER''\nORDER BY title ASC;\n```'),
    ('sql-fundamentals',        'Joins and Aggregate Functions',    'JOINs combine rows from multiple tables, and aggregates such as COUNT, SUM and AVG summarize a group of rows.\n\n```sql\nSELECT cat.name, COUNT(*) AS total\nFROM courses c\nJOIN categories cat ON cat.id = c.category_id\nGROUP BY cat.name;\n```'),
    ('postgresql-for-beginners','Installing and Connecting',        'PostgreSQL is a powerful open-source relational database. After installation, connect with the psql client or any SQL tool using a host, port, database name and credentials.'),
    ('postgresql-for-beginners','Creating Tables with Constraints', 'Constraints keep data valid: NOT NULL, UNIQUE, PRIMARY KEY, FOREIGN KEY and CHECK.\n\n```sql\nCREATE TABLE students (\n    id BIGSERIAL PRIMARY KEY,\n    email VARCHAR(255) NOT NULL UNIQUE\n);\n```'),
    ('postgresql-for-beginners','CRUD with PostgreSQL',             'CRUD stands for Create, Read, Update and Delete: INSERT, SELECT, UPDATE and DELETE statements operate on table rows.'),
    ('database-design-and-er-modeling', 'Entities and Attributes',  'An entity is a thing worth storing (for example, a course), and attributes describe it (title, difficulty). Entity-relationship diagrams draw entities as boxes and attributes as ovals.'),
    ('database-design-and-er-modeling', 'Keys and Relationships',   'Primary keys uniquely identify a row. Foreign keys reference another table and encode one-to-one, one-to-many or many-to-many relationships.'),
    ('database-design-and-er-modeling', 'Normalization to 3NF',     'Normalization removes redundancy. First normal form removes repeating groups, second removes partial dependencies, and third removes transitive dependencies.'),
    ('java-backend-basics',     'Java Syntax and Setup',            'Java is a strongly typed, object-oriented language that runs on the JVM. Set up a JDK and an IDE, then write your first main method.\n\n```java\npublic class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, backend!");\n    }\n}\n```'),
    ('java-backend-basics',     'Classes, Objects and Inheritance', 'Classes are blueprints; objects are instances. Inheritance lets a class reuse and extend the behaviour of a parent class.'),
    ('java-backend-basics',     'Collections and Streams',          'The Collections framework provides List, Set and Map. Streams let you process data with map, filter and reduce pipelines.'),
    ('spring-boot-rest-api',    'Bootstrapping a Spring Boot App',  'Spring Boot scaffolds a web application with embedded Tomcat. The main class uses @SpringBootApplication to enable auto-configuration.'),
    ('spring-boot-rest-api',    'Building a REST Controller',       'A @RestController maps HTTP verbs to Java methods. @GetMapping, @PostMapping and friends define the endpoints.\n\n```java\n@RestController\nclass CourseController {\n    @GetMapping("/courses")\n    List<Course> list() { /* ... */ }\n}\n```'),
    ('spring-boot-rest-api',    'Persistence with Spring Data JPA', 'Spring Data JPA turns entities into database tables. A repository interface gives you CRUD without writing SQL.'),
    ('html-css-javascript-basics', 'Semantic HTML',                 'Semantic tags such as header, main, nav and footer describe the meaning of content, improving accessibility and SEO.\n\n```html\n<main><h1>Learn the Web</h1></main>\n```'),
    ('html-css-javascript-basics', 'Styling with Modern CSS',       'CSS controls presentation. Flexbox and Grid handle layout, while variables and media queries make designs responsive.'),
    ('html-css-javascript-basics', 'JavaScript Fundamentals',       'JavaScript adds interactivity: variables, functions, DOM manipulation and event handling run directly in the browser.'),
    ('data-structures-essentials', 'Arrays and Strings',            'Arrays store elements in contiguous memory with O(1) indexing. Strings are immutable sequences of characters in most languages.'),
    ('data-structures-essentials', 'Linked Lists, Stacks and Queues', 'Linked lists grow dynamically without resizing. Stacks are last-in-first-out; queues are first-in-first-out.'),
    ('data-structures-essentials', 'Trees and Graphs',              'Trees organize data hierarchically; graphs model arbitrary connections. Traversals such as BFS and DFS solve many problems.'),
    ('advanced-postgresql-functions', 'Stored Functions and Triggers', 'Stored functions move logic into the database. Triggers run automatically before or after an event on a table.'),
    ('advanced-postgresql-functions', 'Window Functions',           'Window functions compute values across a set of rows without collapsing them, enabling running totals and rankings.\n\n```sql\nSELECT title,\n       RANK() OVER (ORDER BY review_count DESC) AS rank\nFROM courses;\n```'),
    ('advanced-postgresql-functions', 'Full-Text Search and JSON',  'PostgreSQL supports full-text search through tsvector/tsquery and flexible JSON data through the jsonb type.'),
    ('graphql-api-design',         'Schemas and Types',             'A GraphQL schema declares the types and fields clients can query. The schema is the contract between client and server.'),
    ('graphql-api-design',         'Resolvers and Mutations',       'Resolvers fetch the data for each field. Mutations change server state and return the updated data.'),
    ('data-analytics-with-python', 'pandas DataFrames',             'pandas DataFrames are tabular structures with labelled rows and columns, ideal for cleaning and exploring datasets.'),
    ('data-analytics-with-python', 'Aggregation and Plots',         'Group data with groupby and aggregate, then visualize with matplotlib or seaborn to find patterns.'),
    ('distributed-systems-theory', 'Consistency Models',            'Strong consistency guarantees every read sees the latest write; weaker models trade consistency for availability and latency.'),
    ('distributed-systems-theory', 'Raft Consensus',                'Raft is a consensus algorithm for replicated state machines built on leader election and replicated logs.'),
    ('flash-animation-basics',     'Timeline and Tweening',         'The Flash timeline layers frames; tweening interpolates motion between keyframes.'),
    ('flash-animation-basics',     'ActionScript Basics',           'ActionScript is the scripting language of Flash, similar to JavaScript in syntax.')
) AS cb(course_slug, lesson_title, body)
JOIN public.lessons l ON l.title = cb.lesson_title
JOIN public.courses c ON c.id = l.course_id AND c.slug = cb.course_slug
ON CONFLICT (lesson_id, sequence_order) DO NOTHING;

-- =========================================================
-- 8. Prerequisite graph
-- =========================================================

INSERT INTO public.course_prerequisites (course_id, prerequisite_course_id, required_min_score)
SELECT c.id, p.id, 60.00
FROM (VALUES
    ('postgresql-for-beginners',     'sql-fundamentals'),
    ('advanced-postgresql-functions','postgresql-for-beginners'),
    ('java-backend-basics',          'html-css-javascript-basics'),
    ('spring-boot-rest-api',         'java-backend-basics'),
    ('data-structures-essentials',   'java-backend-basics')
) AS d(course_slug, prerequisite_slug)
JOIN public.courses c ON c.slug = d.course_slug
JOIN public.courses p ON p.slug = d.prerequisite_slug
ON CONFLICT (course_id, prerequisite_course_id) DO NOTHING;

-- =========================================================
-- 9. Second track: Full-Stack Java Developer
-- =========================================================

INSERT INTO public.tracks (title, status, description)
SELECT 'Full-Stack Java Developer', 'PUBLISHED',
       'From HTML, CSS and JavaScript to Java and Spring Boot REST APIs.'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tracks WHERE title = 'Full-Stack Java Developer'
);

INSERT INTO public.track_courses (track_id, course_id, sequence_order)
SELECT t.id, c.id, d.sequence_order
FROM (VALUES
    ('html-css-javascript-basics', 1),
    ('java-backend-basics',        2),
    ('spring-boot-rest-api',       3)
) AS d(course_slug, sequence_order)
JOIN public.tracks t ON t.title = 'Full-Stack Java Developer'
JOIN public.courses c ON c.slug = d.course_slug
ON CONFLICT (track_id, course_id) DO NOTHING;

-- =========================================================
-- 10. Enroll the demo students in the new track
-- (the AFTER INSERT trigger auto-enrolls the published track
-- courses with source = 'track', so prerequisites are not
-- enforced at enroll time -- they gate content access instead)
-- =========================================================

SELECT public.sp_enroll_track(u.id, t.id)
FROM public.users u
CROSS JOIN public.tracks t
WHERE u.email IN ('sultanakhadiza37@gmail.com', 'malihatasnim@gmail.com', 'saikasarara@gmail.com')
  AND t.title = 'Full-Stack Java Developer'
  AND NOT EXISTS (
      SELECT 1
      FROM public.track_enrollments te
      WHERE te.user_id = u.id
        AND te.track_id = t.id
  );

-- =========================================================
-- 11. Demo lesson progress
--
-- Maliha completes Database Design Fundamentals (course 1) so
-- the 'completed' card state and the certificate are visible.
-- Khadiza and Saika keep partial progress so 'continue' and
-- 'enrolled' states remain visible across the catalogue.
-- =========================================================

-- Maliha completes course 1 (all four lessons).
UPDATE public.lesson_progress lp
SET status = 'completed',
    completed_at = COALESCE(lp.completed_at, CURRENT_TIMESTAMP)
WHERE lp.status <> 'completed'
  AND lp.enrollment_id IN (
      SELECT e.id
      FROM public.enrollments e
      JOIN public.users u ON u.id = e.user_id
      JOIN public.courses c ON c.id = e.course_id
      WHERE u.email = 'malihatasnim@gmail.com'
        AND c.slug = 'database-design-fundamentals'
  );

-- Khadiza has started course 1 (first lesson done).
UPDATE public.lesson_progress lp
SET status = 'completed',
    completed_at = COALESCE(lp.completed_at, CURRENT_TIMESTAMP)
WHERE lp.status <> 'completed'
  AND lp.enrollment_id IN (
      SELECT e.id
      FROM public.enrollments e
      JOIN public.users u ON u.id = e.user_id
      JOIN public.courses c ON c.id = e.course_id
      WHERE u.email = 'sultanakhadiza37@gmail.com'
        AND c.slug = 'database-design-fundamentals'
  )
  AND lp.lesson_id IN (
      SELECT l.id
      FROM public.lessons l
      JOIN public.courses c ON c.id = l.course_id
      WHERE c.slug = 'database-design-fundamentals'
        AND l.sequence_order = 1
  );

-- =========================================================
-- 12. Re-align identity sequences after explicit-ID inserts
-- =========================================================

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
    pg_get_serial_sequence('public.lesson_content_blocks', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.lesson_content_blocks)
);

SELECT setval(
    pg_get_serial_sequence('public.tracks', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.tracks)
);

SELECT setval(
    pg_get_serial_sequence('public.enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.enrollments)
);

SELECT setval(
    pg_get_serial_sequence('public.track_enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.track_enrollments)
);

SELECT setval(
    pg_get_serial_sequence('public.lesson_progress', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.lesson_progress)
);
