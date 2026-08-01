/* ==========================================================================
   Demo Seed Data (js/utils/seed.js)
   Loaded by the student / instructor / admin pages. Idempotent: it only
   runs when the course registry (learnova_courses) is empty, then seeds a
   small, realistic dataset so every screen has something to show until the
   real backend lands:
     - 6 courses across tracks in different lifecycle states
     - curricula (modules/lessons) + lesson content (video / notes / links)
     - enrollment + quiz-pass + completion + certificate flags for the demo
       student (sarah.j@example.com)
     - a pending instructor request and a couple of notifications
   ========================================================================== */
(function () {
    'use strict';

    var COURSES_KEY = LearnovaConstants.COURSES_KEY;
    var NOTIFICATIONS_KEY = LearnovaConstants.NOTIFICATIONS_KEY;
    var REQUESTS_KEY = LearnovaConstants.INSTRUCTOR_REQUEST_KEY;

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function setFlag(key) {
        if (!localStorage.getItem(key)) localStorage.setItem(key, '1');
    }

    function ensure(key, value) {
        if (!localStorage.getItem(key)) localStorage.setItem(key, JSON.stringify(value));
    }

    function ensureString(key, value) {
        var existing = localStorage.getItem(key);
        if (!existing || (existing.charAt(0) === '"' && existing.charAt(existing.length - 1) === '"')) {
            localStorage.setItem(key, value);
        }
    }

    function course(slug, title, description, track, status, instructorEmail) {
        return { slug: slug, title: title, description: description, track: track, status: status, instructorEmail: instructorEmail };
    }

    function curriculum(modules) {
        return { modules: modules.map(function (m) { return { title: m[0], lessons: m[1].map(function (l) { return { name: l }; }) }; }) };
    }

    function content(title, description, blocks) {
        return { title: title, description: description, blocks: blocks };
    }

    function video(url, title) { return { type: 'video', url: url, title: title, text: '' }; }
    function article(url, title, text) { return { type: 'article', url: url, title: title, text: text }; }
    function notes(text) { return { type: 'notes', url: '', title: '', text: text }; }
    function pdf(url, title) { return { type: 'pdf', url: url, title: title, text: '' }; }

    function seeded() {
        var raw = localStorage.getItem(COURSES_KEY);
        if (raw) {
            try {
                return JSON.parse(raw).length > 0;
            } catch (err) { /* treat as empty */ }
        }
        return false;
    }

    if (seeded()) return;

    var YOUTUBE = 'https://www.youtube.com/watch?v=';

    var demoCourses = [
        course('database-design-fundamentals', 'Database Design Fundamentals',
            'Core concepts of relational database design: ER modeling and normalization.',
            'Database Engineer', LearnovaConstants.COURSE_STATUS.PUBLISHED, 'david.m@example.com'),
        course('sql-and-query-optimization', 'SQL & Query Optimization',
            'Write efficient SQL and learn how indexes and query plans work.',
            'Database Engineer', LearnovaConstants.COURSE_STATUS.PUBLISHED, 'david.m@example.com'),
        course('intro-to-neo4j', 'Intro to Neo4j Graph Databases',
            'Model connected data with graphs and query it with Cypher.',
            'Database Engineer', LearnovaConstants.COURSE_STATUS.PUBLISHED, 'david.m@example.com'),
        course('python-for-data-science', 'Python for Data Science',
            'Practical Python for data analysis with pandas and Jupyter.',
            'Data Science', LearnovaConstants.COURSE_STATUS.PUBLISHED, 'priya.s@example.com'),
        course('modern-react-typescript', 'Modern React & TypeScript',
            'Build type-safe React applications with modern hooks and tooling.',
            'Frontend Dev', LearnovaConstants.COURSE_STATUS.PENDING, 'david.m@example.com'),
        course('data-warehousing-etl', 'Data Warehousing & ETL',
            'Design data warehouses and build ETL pipelines.',
            'Database Engineer', LearnovaConstants.COURSE_STATUS.DRAFT, 'david.m@example.com')
    ];
    localStorage.setItem(COURSES_KEY, JSON.stringify(demoCourses));

    /* ---- Curricula ---- */
    var curricula = {
        'database-design-fundamentals': curriculum([
            ['Core Concepts', ['Introduction to Databases', 'Entity-Relationship Modeling']],
            ['Normalization', ['First Normal Form', 'Normalizing to 3NF']]
        ]),
        'sql-and-query-optimization': curriculum([
            ['Query Basics', ['SELECT and Joins', 'Subqueries and CTEs']],
            ['Performance', ['Indexes', 'Reading Query Plans']]
        ]),
        'intro-to-neo4j': curriculum([
            ['Graphs', ['Why Graph Databases', 'Cypher Basics']]
        ]),
        'python-for-data-science': curriculum([
            ['Python', ['Python Intro', 'Pandas DataFrames']]
        ]),
        'modern-react-typescript': curriculum([
            ['React', ['Components & Props']]
        ]),
        'data-warehousing-etl': curriculum([
            ['Warehousing', ['Kimball vs Inmon']]
        ])
    };
    Object.keys(curricula).forEach(function (key) {
        ensure('learnova_curriculum_' + key, curricula[key]);
    });

    /* ---- Lesson content (video / notes / article / pdf) ---- */
    function saveLesson(lessonName, record) {
        ensure('learnova_lesson_content_' + slugify(lessonName), record);
    }

    saveLesson('Introduction to Databases',
        content('Introduction to Databases', 'What a database is, why we use them, and the relational model.',
            [video(YOUTUBE + 'dQw4w9WgXcQ', 'Watch: Intro to Databases'),
             notes('# What is a database?\n\nA database is an organized collection of data. Relational databases store data in **tables** with rows and columns.\n\n- **Tables** group related data\n- **Primary keys** uniquely identify rows\n- **Foreign keys** link tables together\n\n> Relational model: data is described using relations (tables).')]));

    saveLesson('Entity-Relationship Modeling',
        content('Entity-Relationship Modeling', 'Design a schema from requirements using ER diagrams.',
            [notes('# ER Modeling\n\nEntities become tables, attributes become columns, relationships become foreign keys.\n\n## Cardinalities\n1. **1:1** one-to-one\n2. **1:N** one-to-many\n3. **M:N** many-to-many (needs a join table)\n\n> A good schema is both simple and expressive.')]));

    saveLesson('First Normal Form',
        content('First Normal Form', 'Atomic columns and no repeating groups.',
            [notes('## 1NF\n- Every column holds atomic values\n- No repeating groups or arrays\n\nApply 1NF before moving to higher normal forms.')]));

    saveLesson('Normalizing to 3NF',
        content('Normalizing to 3NF', 'Remove partial and transitive dependencies.',
            [article('https://en.wikipedia.org/wiki/Database_normalization', 'Database normalization (Wikipedia)',
                     'Reference: the classic 1NF -> 2NF -> 3NF -> BCNF progression.'),
             notes('### Quick checklist\n- 2NF: no partial dependency on a composite key\n- 3NF: no transitive dependency on non-key columns')]));

    saveLesson('SELECT and Joins',
        content('SELECT and Joins', 'Query tables and combine them with joins.',
            [video(YOUTUBE + 'dQw4w9WgXcQ', 'Watch: SQL JOINs'),
             notes('```sql\nSELECT u.name, o.total\nFROM users u\nJOIN orders o ON o.user_id = u.id;\n```\n- `INNER JOIN` keeps matching rows\n- `LEFT JOIN` keeps all left rows')]));

    saveLesson('Subqueries and CTEs',
        content('Subqueries and CTEs', 'Compose queries with subqueries and WITH clauses.',
            [notes('### Common Table Expressions\n```sql\nWITH top AS (\n  SELECT user_id, SUM(total) s\n  FROM orders\n  GROUP BY user_id\n)\nSELECT * FROM top WHERE s > 1000;\n```')]));

    saveLesson('Indexes',
        content('Indexes', 'Speed up lookups and understand index trade-offs.',
            [notes('## Indexes\n- Speed up reads, slow down writes\n- Useful on columns used in `WHERE` and `JOIN`')]));

    saveLesson('Reading Query Plans',
        content('Reading Query Plans', 'Use EXPLAIN to understand how the engine runs your query.',
            [notes('```sql\nEXPLAIN ANALYZE\nSELECT * FROM orders WHERE status = \'open\';\n```\nLook for sequential scans vs index scans.')]));

    saveLesson('Why Graph Databases',
        content('Why Graph Databases', 'When relationships matter more than the records themselves.',
            [notes('# Graphs\n\nGraphs are great for **connected** data: social networks, fraud rings, recommendation paths.\n\n- Nodes = entities\n- Relationships = edges')]));

    saveLesson('Cypher Basics',
        content('Cypher Basics', 'The query language of Neo4j.',
            [video(YOUTUBE + 'dQw4w9WgXcQ', 'Watch: Cypher in 5 minutes'),
             notes('```cypher\nMATCH (p:Person)-[:KNOWS]->(f:Person)\nRETURN p.name, f.name;\n```')]));

    saveLesson('Python Intro',
        content('Python Intro', 'Python syntax, types, and environments.',
            [notes('# Python\n\n```python\nimport pandas as pd\ndf = pd.read_csv("data.csv")\nprint(df.head())\n```')]));

    saveLesson('Pandas DataFrames',
        content('Pandas DataFrames', 'Filter, group, and aggregate tabular data.',
            [pdf('https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', 'Download: pandas cheatsheet')]));

    /* ---- Student activity for the demo student ---- */
    // sarah.j@example.com is enrolled in the published courses
    ['database-design-fundamentals', 'sql-and-query-optimization', 'intro-to-neo4j', 'python-for-data-science']
        .forEach(function (key) { setFlag('learnova_enrolled_' + key); });

    // Passed quizzes drive progress / unlocking
    ['introduction-to-databases', 'entity-relationship-modeling', 'first-normal-form', 'normalizing-to-3nf']
        .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });
    ['select-and-joins', 'subqueries-and-ctes']
        .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });
    ['python-intro']
        .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });

    // Fully completed the first course -> certificate
    setFlag('learnova_course_complete_database-design-fundamentals');
    ensureString('learnova_cert_code_database-design-fundamentals', 'LRV-8K3F-9Q2X');

    /* ---- Notifications ---- */
    ensure(NOTIFICATIONS_KEY, [
        { id: Date.now(), email: 'sarah.j@example.com', message: 'Welcome to Learnova! Explore the catalog and enroll in your first course.', is_read: false, created_at: new Date().toISOString() },
        { id: Date.now() + 1, email: 'sarah.j@example.com', message: 'Certificate earned: Database Design Fundamentals (LRV-8K3F-9Q2X).', is_read: false, created_at: new Date().toISOString() }
    ]);

    /* ---- One pending instructor request for the admin demo ---- */
    ensure(REQUESTS_KEY, [
        { id: Date.now(), name: 'Priya Sharma', email: 'priya.s@example.com', note: 'Wants to teach Data Science courses.', status: 'pending', created_at: new Date().toISOString() }
    ]);
})();
