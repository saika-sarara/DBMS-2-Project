/* ==========================================================================
   Learnova Mock Adapter (window.LearnovaMockAdapter)
   Offline fallback for LearnovaApiClient. When the Spring Boot backend at
   LearnovaConstants.API_BASE_URL is unreachable, apiClient.js routes every
   request here. This adapter mirrors the REST surface of js/api/*.js and
   owns ALL demo data: it seeds the learnova_* localStorage keys itself
   (users + courses + curricula + lesson content + demo activity) so the
   demo keeps working with no backend running and no seed script.

   Business rules that used to live in page scripts live here (the future
   backend owns them):
     - auth: credentials + active / suspended / banned blocking (spec 1.1)
     - courses: lifecycle draft -> pending -> published, curriculum, lessons
     - enrollment gated by prerequisites (AND logic) + bypass exams (spec 3)
     - quiz attempts: 5 random of 20, >=60% pass, 3/day resetting at midnight
     - auto-issued LRV-XXXX-XXXX certificates on course completion (spec 8)
     - reviews (one per student, immutable) (spec 7)
     - notifications + instructor requests (specs 1.3 / 10)
     - admin: users, role/status changes, request moderation, publishing
   ========================================================================== */

window.LearnovaMockAdapter = (function () {
    'use strict';

    var GRADING = LearnovaConstants.GRADING;
    var QUIZ = LearnovaConstants.QUIZ_DEFAULTS;
    var CERT = LearnovaConstants.CERTIFICATE;
    var COURSE_STATUS = LearnovaConstants.COURSE_STATUS;
    var REQ_STATUS = LearnovaConstants.INSTRUCTOR_REQUEST_STATUS;

    var USERS_KEY = LearnovaConstants.USERS_KEY;
    var COURSES_KEY = LearnovaConstants.COURSES_KEY;
    var REQUESTS_KEY = LearnovaConstants.INSTRUCTOR_REQUEST_KEY;
    var NOTIFICATIONS_KEY = LearnovaConstants.NOTIFICATIONS_KEY;
    var TRACKS_KEY = 'learnova_tracks';
    var BANK_KEY = 'learnova_quiz_bank_';

    /* ---------- Storage helpers ---------- */

    function readJSON(key, fallback) {
        var raw = localStorage.getItem(key);
        if (raw) {
            try { return JSON.parse(raw); } catch (e) { /* corrupt: fall back */ }
        }
        return fallback;
    }

    function writeJSON(key, value) {
        localStorage.setItem(key, JSON.stringify(value));
    }

    function getFlag(key) { return localStorage.getItem(key) === '1'; }
    function setFlag(key) { localStorage.setItem(key, '1'); }

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function fail(message, status) {
        var err = new Error(message);
        err.status = status || 400;
        throw err;
    }

    /* ---------- Demo registry + seeding ---------- */

    /* Mirrors the users that login.js / register.js used to seed inline.
       Matches the V8 + V17 seed accounts of the real backend. */
    var DEMO_USERS = [
        { id: 7, name: 'Admin User', email: 'admin@learnova.com', password: 'ChangeMe_StrongPassword', roles: ['Admin'], status: 'active', joined: 'Dec 2025' },
        { id: 8, name: 'Khadiza Sultana', email: 'sultanakhadiza37@gmail.com', password: 'password123', roles: ['Admin'], status: 'active', joined: 'Mar 2026' },
        { id: 9, name: 'Maliha Tasnim', email: 'malihatasnim@gmail.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Mar 2026' },
        { id: 10, name: 'Saika Sarara', email: 'saikasarara@gmail.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Mar 2026' },
        { id: 11, name: 'Rafi Ahmed', email: 'rafiahmed@gmail.com', password: 'password123', roles: ['Instructor'], status: 'active', joined: 'Mar 2026' },
        { id: 12, name: 'Nusrat Jahan', email: 'nusratjahan@gmail.com', password: 'password123', roles: ['Instructor'], status: 'active', joined: 'Mar 2026' }
    ];

    function ensureSeed() {
        if (!localStorage.getItem(USERS_KEY)) {
            writeJSON(USERS_KEY, DEMO_USERS);
        }
        seedDemoData();
    }

    /* ---------- Demo course data (was js/utils/seed.js) ---------- */

    /* Ported from seed.js so the mock owns ALL demo data and pages no longer
       need to include seed.js. Idempotent: only runs when the course registry
       is empty, then seeds courses, curricula, lesson content, student
       activity, notifications, and one pending instructor request. */
    function seedDemoData() {
        if (seeded()) return;

        function ensure(key, value) {
            if (!localStorage.getItem(key)) localStorage.setItem(key, JSON.stringify(value));
        }

        function ensureString(key, value) {
            var existing = localStorage.getItem(key);
            if (!existing || (existing.charAt(0) === '"' && existing.charAt(existing.length - 1) === '"')) {
                localStorage.setItem(key, value);
            }
        }

        function seeded() {
            var raw = localStorage.getItem(COURSES_KEY);
            if (raw) {
                try { return JSON.parse(raw).length > 0; } catch (e) { /* treat as empty */ }
            }
            return false;
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

        function video(url, title) { return { type: 'youtube', url: url, title: title, text: '' }; }
        function article(url, title, text) { return { type: 'link', url: url, title: title, text: text }; }
        function notes(text) { return { type: 'markdown', url: '', title: '', text: text }; }
        function pdf(url, title) { return { type: 'pdf', url: url, title: title, text: '' }; }

        var YOUTUBE = 'https://www.youtube.com/watch?v=';

        var demoCourses = [
            course('database-design-fundamentals', 'Database Design Fundamentals',
                'Core concepts of relational database design: ER modeling and normalization.',
                'Database Engineer', COURSE_STATUS.PUBLISHED, 'rafiahmed@gmail.com'),
            course('sql-and-query-optimization', 'SQL & Query Optimization',
                'Write efficient SQL and learn how indexes and query plans work.',
                'Database Engineer', COURSE_STATUS.PUBLISHED, 'rafiahmed@gmail.com'),
            course('intro-to-neo4j', 'Intro to Neo4j Graph Databases',
                'Model connected data with graphs and query it with Cypher.',
                'Database Engineer', COURSE_STATUS.PUBLISHED, 'rafiahmed@gmail.com'),
            course('python-for-data-science', 'Python for Data Science',
                'Practical Python for data analysis with pandas and Jupyter.',
                'Data Science', COURSE_STATUS.PUBLISHED, 'nusratjahan@gmail.com'),
            course('modern-react-typescript', 'Modern React & TypeScript',
                'Build type-safe React applications with modern hooks and tooling.',
                'Frontend Dev', COURSE_STATUS.PENDING, 'nusratjahan@gmail.com'),
            course('data-warehousing-etl', 'Data Warehousing & ETL',
                'Design data warehouses and build ETL pipelines.',
                'Database Engineer', COURSE_STATUS.DRAFT, 'nusratjahan@gmail.com')
        ];
        demoCourses.forEach(function (c, i) { c.id = i + 1; });

        /* Track registry: derived from the demo course tracks so the mock
           mirrors the backend tracks table (numeric id + slug + courseIds). */
        var tracksById = {};
        var trackList = [];
        demoCourses.forEach(function (c) {
            if (!c.track) return;
            var slug = slugify(c.track);
            if (!tracksById[slug]) {
                tracksById[slug] = { id: trackList.length + 1, slug: slug, title: c.track, courseIds: [] };
                trackList.push(tracksById[slug]);
            }
            tracksById[slug].courseIds.push(c.id);
        });
        demoCourses.forEach(function (c) {
            var t = c.track ? tracksById[slugify(c.track)] : null;
            c.trackId = t ? t.id : null;
        });
        writeJSON(COURSES_KEY, demoCourses);
        writeJSON(TRACKS_KEY, trackList);

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
        ['database-design-fundamentals', 'sql-and-query-optimization', 'intro-to-neo4j', 'python-for-data-science']
            .forEach(function (key) { setFlag('learnova_enrolled_' + key); });

        ['introduction-to-databases', 'entity-relationship-modeling', 'first-normal-form', 'normalizing-to-3nf']
            .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });
        ['select-and-joins', 'subqueries-and-ctes']
            .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });
        ['python-intro']
            .forEach(function (key) { setFlag('learnova_quiz_pass_' + key); });

        setFlag('learnova_course_complete_database-design-fundamentals');
        ensureString('learnova_cert_code_database-design-fundamentals', 'LRV-8K3F-9Q2X');

        /* ---- Notifications ---- */
        ensure(NOTIFICATIONS_KEY, [
            { id: Date.now(), email: 'malihatasnim@gmail.com', message: 'Welcome to Learnova! Explore the catalog and enroll in your first course.', is_read: false, created_at: new Date().toISOString() },
            { id: Date.now() + 1, email: 'saikasarara@gmail.com', message: 'Welcome to Learnova! Explore the catalog and enroll in your first course.', is_read: false, created_at: new Date().toISOString() }
        ]);

        /* ---- One pending instructor request for the admin demo ---- */
        ensure(REQUESTS_KEY, [
            { id: Date.now(), name: 'Saika Sarara', email: 'saikasarara@gmail.com', note: 'Wants to teach Data Science courses.', status: REQ_STATUS.PENDING, created_at: new Date().toISOString() }
        ]);
    }

    /* ---------- Session ---------- */

    function currentUser() {
        if (window.LearnovaSession && typeof LearnovaSession.currentUser === 'function') {
            return LearnovaSession.currentUser();
        }
        return null;
    }

    function hasRole(role) {
        var user = currentUser();
        if (!user) return false;
        var roles = Array.isArray(user.roles) && user.roles.length ? user.roles : (user.role ? [user.role] : []);
        return roles.indexOf(role) !== -1;
    }

    /* True when the active session was created by the mock (demo login or a
       request that fell through to the mock). Such sessions only exist in the
       mock's storage, so apiClient can skip the real fetch entirely. */
    function isMockSession() {
        var user = currentUser();
        return !!(user && user.token && String(user.token).indexOf('demo-token-') === 0);
    }

    /* ---------- Notifications (spec 10) ---------- */

    function pushNotification(message, email) {
        var user = currentUser();
        var items = readJSON(NOTIFICATIONS_KEY, []);
        items.unshift({
            id: Date.now(),
            email: email || (user ? user.email : ''),
            message: message,
            is_read: false,
            created_at: new Date().toISOString()
        });
        writeJSON(NOTIFICATIONS_KEY, items.slice(0, 20));
    }

    /* ---------- Courses ---------- */

    function readCourses() { return readJSON(COURSES_KEY, []); }
    function writeCourses(list) { writeJSON(COURSES_KEY, list); }

    function findCourse(id) {
        var courses = readCourses();
        for (var i = 0; i < courses.length; i++) {
            if (String(courses[i].slug) === String(id) || String(courses[i].id) === String(id)) return courses[i];
        }
        return null;
    }

    function indexOfCourse(courses, id) {
        for (var i = 0; i < courses.length; i++) {
            if (String(courses[i].slug) === String(id) || String(courses[i].id) === String(id)) return i;
        }
        return -1;
    }

    function readCurriculum(courseSlug) {
        return readJSON('learnova_curriculum_' + courseSlug, { modules: [] });
    }

    function writeCurriculum(courseSlug, body) {
        var value = { modules: (body && body.modules) || [] };
        localStorage.setItem('learnova_curriculum_' + courseSlug, JSON.stringify(value));
        return value;
    }

    function lessonsOf(courseSlug) {
        var curriculum = readCurriculum(courseSlug);
        var names = [];
        curriculum.modules.forEach(function (m) {
            (m.lessons || []).forEach(function (l) { names.push(l.name); });
        });
        return names;
    }

    function readLessonContent(lessonSlug) {
        return readJSON('learnova_lesson_content_' + lessonSlug, null);
    }

    function writeLessonContent(lessonSlug, body) {
        localStorage.setItem('learnova_lesson_content_' + lessonSlug, JSON.stringify(body));
        return body;
    }

    /* ---------- Progress helpers (lesson flags) ---------- */

    function lessonPassed(name) {
        var slug = slugify(name);
        return getFlag('learnova_quiz_pass_' + slug) || getFlag('learnova_bypass_pass_' + slug);
    }

    function progressOf(courseSlug) {
        var lessons = lessonsOf(courseSlug);
        var done = lessons.filter(lessonPassed).length;
        return { total: lessons.length, done: done, pct: lessons.length ? Math.round(done / lessons.length * 100) : 0 };
    }

    function isEnrolled(courseSlug) { return getFlag('learnova_enrolled_' + courseSlug); }
    function isCompleted(courseSlug) { return getFlag('learnova_course_complete_' + courseSlug); }
    function certCodeOf(courseSlug) { return localStorage.getItem('learnova_cert_code_' + courseSlug); }

    /* Course detail returned by GET /courses/:id carries computed state. */
    function enrichCourse(course) {
        var out = Object.assign({}, course);
        out.enrolled = isEnrolled(course.slug);
        out.completed = isCompleted(course.slug);
        out.certCode = certCodeOf(course.slug);
        var lessons = lessonsOf(course.slug);
        var done = lessons.filter(lessonPassed).length;
        out.progress = {
            total: lessons.length,
            done: done,
            pct: lessons.length ? Math.round(done / lessons.length * 100) : 0,
            lessons: lessons.map(function (name) {
                return { name: name, passed: lessonPassed(name) };
            })
        };
        out.prereqs = (course.prereqs || []).map(function (p) {
            var pSlug = p.slug || slugify(p.title || '');
            return { slug: pSlug, title: p.title, satisfied: prereqSatisfied({ slug: pSlug }) };
        });
        out.trackCourses = course.trackCourses || [];
        return out;
    }

    function courseCreate(body) {
        var user = currentUser();
        var title = String((body && body.title) || '').trim();
        if (!title) fail('Course title is required.');
        var slug = (body && body.slug) || slugify(title);
        var courses = readCourses();
        var idx = indexOfCourse(courses, slug);
        var record = Object.assign({}, idx !== -1 ? courses[idx] : {}, {
            slug: slug,
            title: title,
            description: (body && body.description) || '',
            track: (body && body.track) || '',
            status: (body && body.status) || COURSE_STATUS.DRAFT,
            instructorEmail: (body && body.instructorEmail) || (user ? user.email : '')
        });
        if (idx === -1) {
            courses.unshift(record);
        } else {
            courses[idx] = record;
        }
        writeCourses(courses);
        if (!localStorage.getItem('learnova_curriculum_' + slug)) {
            localStorage.setItem('learnova_curriculum_' + slug, JSON.stringify({ modules: [] }));
        }
        return enrichCourse(record);
    }

    function courseUpdate(id, body) {
        var courses = readCourses();
        var idx = indexOfCourse(courses, id);
        if (idx === -1) fail('Course not found.', 404);
        var record = Object.assign({}, courses[idx], body || {});
        if (body && body.title && body.title !== courses[idx].title) {
            record.slug = slugify(body.title);
        }
        courses[idx] = record;
        writeCourses(courses);
        return enrichCourse(record);
    }

    function courseRemove(id) {
        var courses = readCourses();
        var next = courses.filter(function (c) {
            return String(c.slug) !== String(id) && String(c.id) !== String(id);
        });
        if (next.length === courses.length) fail('Course not found.', 404);
        writeCourses(next);
        localStorage.removeItem('learnova_curriculum_' + id);
        return { ok: true };
    }

    /* ---------- Prerequisites (spec 3.1) ---------- */

    function prereqSatisfied(prereq) {
        var slug = prereq.slug || slugify(prereq.title || '');
        return getFlag('learnova_course_complete_' + slug) || getFlag('learnova_bypass_pass_' + slug);
    }

    function getPrerequisites(courseId) {
        var course = findCourse(courseId);
        return (course && course.prereqs ? course.prereqs : []).map(function (p) {
            var pSlug = p.slug || slugify(p.title || '');
            return { slug: pSlug, title: p.title, satisfied: prereqSatisfied({ slug: pSlug }) };
        });
    }

    function setPrerequisites(courseId, body) {
        var courses = readCourses();
        var idx = indexOfCourse(courses, courseId);
        if (idx === -1) fail('Course not found.', 404);
        var ids = (body && body.prerequisiteIds) || [];
        var prereqs = ids.map(function (id) {
            var c = findCourse(id);
            return { slug: c ? c.slug : String(id), title: c ? c.title : String(id) };
        });
        courses[idx].prereqs = prereqs;
        writeCourses(courses);
        return prereqs;
    }

    /* ---------- Enrollment (spec 3) — mirrors the backend REST contract ----------
       Routes, param names and payload shapes match EnrollmentController. The
       real backend enforces every rule in the database. The mock mirrors the
       same contract; like the database, it delegates the prerequisite DECISION
       to a prerequisite engine contract (see prerequisiteEngineAccess below)
       instead of computing it in the enrollment path. */

    function ensureTracks() {
        var tracks = readJSON(TRACKS_KEY, []);
        if (tracks.length) return tracks;
        var bySlug = {};
        var list = [];
        readCourses().forEach(function (c) {
            if (!c.track) return;
            var slug = slugify(c.track);
            if (!bySlug[slug]) {
                bySlug[slug] = { id: list.length + 1, slug: slug, title: c.track, courseIds: [] };
                list.push(bySlug[slug]);
            }
            bySlug[slug].courseIds.push(c.id || c.slug);
        });
        writeJSON(TRACKS_KEY, list);
        return list;
    }

    function findTrack(id) {
        var tracks = ensureTracks();
        for (var i = 0; i < tracks.length; i++) {
            if (String(tracks[i].id) === String(id) || String(tracks[i].slug) === String(id)) return tracks[i];
        }
        return null;
    }

    function enrollmentResponse(course) {
        var prog = progressOf(course.slug);
        var completed = isCompleted(course.slug);
        var entityId = course.id || course.slug;
        return {
            enrollmentId: entityId,
            entityId: entityId,
            entityTitle: course.title,
            entityType: 'COURSE',
            status: completed ? 'completed' : 'active',
            progressPct: prog.pct,
            source: 'standalone',
            enrolledAt: null,
            completedAt: null,
            alreadyEnrolled: isEnrolled(course.slug)
        };
    }

    /* Prerequisite engine contract (TEMPORARY placeholder).
       Mirrors the database contract fn_prerequisite_engine_course_access:
       the enrollment path delegates the prerequisite decision to this engine
       and never computes it locally. Owned by the (future) prerequisite
       module; returns "allowed" until a real engine exists. */
    function prerequisiteEngineAccess(studentId, courseId) {
        return {
            allowed: true,
            reasonCode: 'PREREQ_ENGINE_PENDING',
            message: 'Prerequisite engine module is not connected yet.',
            blockingCourseId: null
        };
    }

    function enrollCourse(courseId) {
        var course = findCourse(courseId);
        if (!course) fail('Course not found.', 404);
        var user = currentUser();
        var engine = prerequisiteEngineAccess(user && user.id, course.id || course.slug);
        if (!engine.allowed) {
            fail('Enrollment blocked (LTP01). ' + (engine.message || 'Prerequisites are not satisfied.'));
        }
        if (!isEnrolled(course.slug)) {
            setFlag('learnova_enrolled_' + course.slug);
            pushNotification('You enrolled in "' + course.title + '". The first lesson is unlocked.');
        }
        return enrollmentResponse(course);
    }

    function enrollTrack(trackId) {
        var track = findTrack(trackId);
        if (!track) fail('Track not found.', 404);
        (track.courseIds || []).forEach(function (courseId) {
            var course = findCourse(courseId);
            if (!course || isEnrolled(course.slug)) return;
            setFlag('learnova_enrolled_' + course.slug);
            pushNotification('You enrolled in "' + course.title + '" via the "' + track.title + '" track.');
        });
        return { entityId: track.id, entityTitle: track.title, entityType: 'TRACK', status: 'active', progressPct: 0, source: 'track', alreadyEnrolled: true };
    }

    function myCourseEnrollments() {
        return readCourses().filter(function (c) { return isEnrolled(c.slug); }).map(enrollmentResponse);
    }

    function myTrackEnrollments() {
        return ensureTracks().filter(function (t) {
            return (t.courseIds || []).some(function (courseId) {
                var c = findCourse(courseId);
                return c && isEnrolled(c.slug);
            });
        }).map(function (t) {
            var first = t.courseIds.length ? findCourse(t.courseIds[0]) : null;
            var prog = first ? progressOf(first.slug) : { pct: 0 };
            return {
                enrollmentId: t.id,
                entityId: t.id,
                entityTitle: t.title,
                entityType: 'TRACK',
                status: 'active',
                progressPct: prog.pct,
                source: 'track',
                enrolledAt: null,
                completedAt: null,
                alreadyEnrolled: true
            };
        });
    }

    function courseAccess(courseId) {
        var course = findCourse(courseId);
        if (!course) fail('Course not found.', 404);
        var user = currentUser();
        var engine = prerequisiteEngineAccess(user && user.id, course.id || course.slug);
        var accessible = isEnrolled(course.slug) || engine.allowed;
        return {
            courseId: course.id || course.slug,
            accessible: accessible,
            reasonCode: accessible ? null : engine.reasonCode,
            reason: accessible ? null : engine.message,
            enrollmentStatus: isEnrolled(course.slug) ? (isCompleted(course.slug) ? 'completed' : 'active') : null,
            progressPct: progressOf(course.slug).pct,
            blockingCourseId: engine.blockingCourseId,
            blockingCourseTitle: null
        };
    }

    function enrollmentStats() {
        var users = readJSON(USERS_KEY, []);
        var courses = readCourses();
        var activeStudents = users.filter(function (u) {
            var roles = Array.isArray(u.roles) && u.roles.length ? u.roles : (u.role ? [u.role] : []);
            return roles.indexOf(LearnovaConstants.ROLES.STUDENT) !== -1 &&
                u.status === LearnovaConstants.ACCOUNT_STATUS.ACTIVE;
        }).length;
        var totalEnrollments = courses.filter(function (c) { return isEnrolled(c.slug); }).length;
        return {
            totalUsers: users.length,
            activeStudents: activeStudents,
            totalCourses: courses.length,
            publishedCourses: courses.filter(function (c) { return c.status === COURSE_STATUS.PUBLISHED; }).length,
            totalEnrollments: totalEnrollments,
            activeEnrollments: totalEnrollments,
            completedEnrollments: courses.filter(function (c) { return isCompleted(c.slug); }).length,
            distinctStudents: 1
        };
    }

    function myEnrollments() {
        return readCourses().filter(function (c) { return isEnrolled(c.slug); }).map(enrichCourse);
    }

    /* ---------- Quiz attempts (spec 5) ---------- */

    var DEFAULT_BANK = [
        { q: 'What does SQL stand for?', options: ['Structured Query Language', 'Simple Question Language', 'Standard Query List', 'Sequential Query Logic'], answer: 'A' },
        { q: 'Which clause is used to retrieve data from a table?', options: ['GET', 'SELECT', 'OPEN', 'EXTRACT'], answer: 'B' },
        { q: 'Which keyword sorts the results of a query?', options: ['SORT BY', 'GROUP BY', 'ORDER BY', 'ARRANGE BY'], answer: 'C' },
        { q: 'Which statement is used to add a new row to a table?', options: ['ADD ROW', 'INSERT INTO', 'INSERT ROW', 'PUT'], answer: 'B' },
        { q: 'What is a primary key?', options: ['The first key added to a table', 'A column that uniquely identifies each row', 'A reference to another table', 'An index on a column'], answer: 'B' },
        { q: 'Which operator selects values within a given range?', options: ['BETWEEN', 'IN RANGE', 'LIKE', 'WITHIN'], answer: 'A' },
        { q: 'Which join returns only the matching rows from both tables?', options: ['LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'CROSS JOIN'], answer: 'C' },
        { q: 'What does COUNT(*) return?', options: ['The number of non-null rows in a column', 'The total number of rows in the table', 'The sum of a numeric column', 'The first row of the table'], answer: 'B' },
        { q: 'Which keyword removes duplicate values from the result?', options: ['UNIQUE', 'SEPARATE', 'NO DUP', 'DISTINCT'], answer: 'D' },
        { q: 'What is a foreign key?', options: ['The primary key of the same table', 'An alternate key', 'A column that references another table\'s primary key', 'A clustered index'], answer: 'C' },
        { q: 'Which command deletes rows from a table?', options: ['REMOVE', 'DELETE FROM', 'DROP ROW', 'CLEAR'], answer: 'B' },
        { q: 'Which clause filters groups created by GROUP BY?', options: ['WHERE', 'FILTER', 'HAVING', 'LIMIT'], answer: 'C' },
        { q: 'What is a transaction?', options: ['A single query', 'A sequence of operations treated as one unit', 'A backup job', 'A stored procedure'], answer: 'B' },
        { q: 'Which command removes an entire table and its structure?', options: ['DELETE TABLE', 'REMOVE TABLE', 'DROP TABLE', 'ERASE TABLE'], answer: 'C' },
        { q: 'Which function returns the largest value in a column?', options: ['TOP()', 'MAX()', 'LARGEST()', 'HIGHEST()'], answer: 'B' },
        { q: 'What does a LEFT JOIN preserve?', options: ['Only matching rows', 'All rows from the right table', 'All rows from the left table plus matching right rows', 'No rows'], answer: 'C' },
        { q: 'Which statement creates a new table?', options: ['ADD TABLE', 'CREATE TABLE', 'MAKE TABLE', 'BUILD TABLE'], answer: 'B' },
        { q: 'What does an index speed up?', options: ['Data deletion', 'Table creation', 'Query retrieval', 'User login'], answer: 'C' },
        { q: 'Which constraint ensures all values in a column are different?', options: ['UNIQUE', 'CHECK', 'NOT NULL', 'DEFAULT'], answer: 'A' },
        { q: 'What does ETL stand for in a data pipeline?', options: ['Export, Transfer, Log', 'Execute, Test, Launch', 'Extract, Transform, Load', 'Encode, Transmit, Listen'], answer: 'C' }
    ];

    function readBank(lessonKey) { return readJSON(BANK_KEY + lessonKey, null); }

    function writeBank(lessonKey, bank) {
        localStorage.setItem(BANK_KEY + lessonKey, JSON.stringify(bank));
    }

    function ensureBank(lessonKey) {
        var bank = readBank(lessonKey);
        if (!bank || !bank.length) {
            bank = DEFAULT_BANK.map(function (q, i) {
                return { id: i + 1, text: q.q, options: q.options, correct: q.answer };
            });
            writeBank(lessonKey, bank);
        }
        return bank;
    }

    function allBanks() {
        var out = [];
        for (var i = 0; i < localStorage.length; i++) {
            var key = localStorage.key(i);
            if (key && key.indexOf(BANK_KEY) === 0) {
                var bank = readJSON(key, null);
                if (Array.isArray(bank)) out.push({ key: key, questions: bank });
            }
        }
        return out;
    }

    function findQuestion(bank, id) {
        for (var i = 0; i < bank.length; i++) {
            if (String(bank[i].id) === String(id)) return bank[i];
        }
        return null;
    }

    function shuffle(array) {
        for (var i = array.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = array[i];
            array[i] = array[j];
            array[j] = tmp;
        }
        return array;
    }

    function todayStr() {
        var d = new Date();
        return d.getFullYear() + '-' +
            String(d.getMonth() + 1).padStart(2, '0') + '-' +
            String(d.getDate()).padStart(2, '0');
    }

    function attemptKey(lessonKey, bypass) {
        return (bypass ? 'learnova_bypass_' : 'learnova_quiz_') + lessonKey;
    }

    function attemptRecord(lessonKey, bypass) {
        var raw = localStorage.getItem(attemptKey(lessonKey, bypass));
        var record = raw ? JSON.parse(raw) : { date: '', used: 0 };
        if (record.date !== todayStr()) record = { date: todayStr(), used: 0 };
        return record;
    }

    function saveAttempt(lessonKey, bypass, record) {
        localStorage.setItem(attemptKey(lessonKey, bypass), JSON.stringify(record));
    }

    /* Pass state + remaining daily attempts for a lesson quiz / bypass exam. */
    function quizStatus(lessonKey, bypass) {
        var passKey = (bypass ? 'learnova_bypass_pass_' : 'learnova_quiz_pass_') + lessonKey;
        var record = attemptRecord(lessonKey, bypass);
        var limit = bypass ? GRADING.DAILY_BYPASS_ATTEMPTS : GRADING.DAILY_QUIZ_ATTEMPTS;
        return {
            passed: getFlag(passKey),
            used: record.used,
            attemptsLeft: Math.max(0, limit - record.used),
            limit: limit,
            exhausted: record.used >= limit
        };
    }

    /* Auto-issue a certificate once every lesson quiz is passed (spec 8.1). */
    function checkAndIssueCert(courseSlug) {
        var course = findCourse(courseSlug);
        if (!course || !isEnrolled(course.slug)) return null;
        var lessons = lessonsOf(course.slug);
        if (!lessons.length) return null;
        if (!lessons.every(lessonPassed)) return null;

        setFlag('learnova_course_complete_' + course.slug);
        var code = certCodeOf(course.slug);
        if (!code) {
            code = generateCertCode();
            localStorage.setItem('learnova_cert_code_' + course.slug, code);
            localStorage.setItem('learnova_cert_issued_' + course.slug, new Date().toISOString());
            pushNotification('Course completed! Your certificate (' + code + ') has been issued.');
        }
        return code;
    }

    function submitQuizAttempt(courseId, lessonId, body) {
        var lessonKey = slugify(lessonId);
        var bypass = !!(body && body.bypass);
        var passKey = (bypass ? 'learnova_bypass_pass_' : 'learnova_quiz_pass_') + lessonKey;

        if (getFlag(passKey)) {
            return { score: null, passed: true, alreadyPassed: true, attemptsLeft: 0, exhausted: false, correctAnswers: [] };
        }

        var record = attemptRecord(lessonKey, bypass);
        var limit = bypass ? GRADING.DAILY_BYPASS_ATTEMPTS : GRADING.DAILY_QUIZ_ATTEMPTS;
        if (record.used >= limit) {
            fail('Daily attempt limit reached. The quiz unlocks again at midnight (00:00).');
        }

        var bank = ensureBank(lessonKey);
        var answers = (body && body.answers) || [];
        var total = answers.length;
        var correct = 0;
        answers.forEach(function (answer) {
            var q = findQuestion(bank, answer.id);
            if (q && answer.selected === q.correct) correct++;
        });
        var score = total ? Math.round(correct / total * 100) : 0;
        var passed = score >= GRADING.PASSING_SCORE;

        if (passed) {
            setFlag(passKey);
            var correctAnswers = answers.map(function (answer) {
                var q = findQuestion(bank, answer.id);
                return { id: answer.id, correct: q ? q.correct : null };
            });
            if (!bypass) checkAndIssueCert(String(courseId));
            return {
                score: score,
                passed: true,
                alreadyPassed: false,
                attemptsLeft: Math.max(0, limit - record.used),
                exhausted: false,
                correctAnswers: correctAnswers
            };
        }

        record.used += 1;
        saveAttempt(lessonKey, bypass, record);
        return {
            score: score,
            passed: false,
            alreadyPassed: false,
            attemptsLeft: Math.max(0, limit - record.used),
            exhausted: record.used >= limit,
            correctAnswers: []
        };
    }

    /* ---------- Certificates (spec 8) ---------- */

    function generateCertCode() {
        var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        var segs = [];
        for (var s = 0; s < CERT.SEGMENTS; s++) {
            var out = '';
            for (var i = 0; i < CERT.SEGMENT_LENGTH; i++) {
                out += chars[Math.floor(Math.random() * chars.length)];
            }
            segs.push(out);
        }
        return CERT.CODE_PREFIX + '-' + segs.join('-');
    }

    function myCertificates() {
        return readCourses().filter(function (c) { return certCodeOf(c.slug); }).map(function (c) {
            return {
                courseId: c.slug,
                courseTitle: c.title,
                code: certCodeOf(c.slug),
                issuedAt: localStorage.getItem('learnova_cert_issued_' + c.slug) || null
            };
        });
    }

    function generateCertificate(body) {
        var course = findCourse(body && body.courseId);
        if (!course) fail('Course not found.', 404);
        var code = checkAndIssueCert(course.slug);
        if (!code) fail('This course is not complete yet. Pass every lesson quiz (≥60%) to earn your certificate.');
        return {
            courseId: course.slug,
            courseTitle: course.title,
            code: code,
            issuedAt: localStorage.getItem('learnova_cert_issued_' + course.slug) || null
        };
    }

    /* ---------- Reviews (spec 7) ---------- */

    function listReviews(courseId) {
        return readJSON('learnova_reviews_' + slugify(courseId), []);
    }

    function createReview(courseId, body) {
        var course = findCourse(courseId);
        var user = currentUser();
        if (!user || !user.email) fail('You must be signed in to review a course.');
        var slug = course ? course.slug : slugify(courseId);
        var key = 'learnova_reviews_' + slug;
        var reviews = readJSON(key, []);
        for (var i = 0; i < reviews.length; i++) {
            if (reviews[i].email === user.email) {
                fail('You have already reviewed this course. Reviews cannot be edited or deleted.');
            }
        }
        var rating = Math.max(1, Math.min(5, Number(body && body.rating) || 0));
        if (!rating) fail('Please provide a star rating between 1 and 5.');
        var review = {
            id: Date.now(),
            email: user.email,
            name: user.name,
            rating: rating,
            comment: (body && body.comment) || '',
            at: new Date().toISOString()
        };
        reviews.push(review);
        writeJSON(key, reviews);
        pushNotification('You reviewed "' + (course ? course.title : slug) + '" with ' + rating + ' stars.');
        return review;
    }

    /* ---------- Instructor requests (spec 1.3) ---------- */

    function myInstructorRequest() {
        var user = currentUser();
        if (!user || !user.email) return null;
        var mine = readJSON(REQUESTS_KEY, []).filter(function (r) { return r.email === user.email; });
        return mine.length ? mine[mine.length - 1] : null;
    }

    function createInstructorRequest(body) {
        var user = currentUser();
        if (!user || !user.email) fail('You must be signed in to request the Instructor role.');
        var existing = readJSON(REQUESTS_KEY, []).filter(function (r) {
            return r.email === user.email && r.status === REQ_STATUS.PENDING;
        });
        if (existing.length) fail('You already have a pending request. An Admin will review it.');
        var request = {
            id: Date.now(),
            email: user.email,
            name: user.name,
            note: (body && body.note) || '',
            status: REQ_STATUS.PENDING,
            created_at: new Date().toISOString()
        };
        var requests = readJSON(REQUESTS_KEY, []);
        requests.push(request);
        writeJSON(REQUESTS_KEY, requests);
        return request;
    }

    /* ---------- Users / profile (mirrors UserController) ---------- */

    function profileOf(user) {
        if (!user) return null;
        var roles = Array.isArray(user.roles) && user.roles.length
            ? user.roles
            : (user.role ? [user.role] : [LearnovaConstants.ROLES.STUDENT]);
        return {
            id: user.id,
            email: user.email,
            fullName: user.fullName || user.name || '',
            name: user.fullName || user.name || '',
            roles: roles,
            role: roles[0],
            status: user.status || LearnovaConstants.ACCOUNT_STATUS.ACTIVE
        };
    }

    function myProfile() {
        return profileOf(currentUser());
    }

    function updateMyProfile(body) {
        var user = currentUser();
        if (!user || !user.id) fail('You must be signed in to update your profile.', 401);
        var users = readJSON(USERS_KEY, []);
        var record = null;
        for (var i = 0; i < users.length; i++) {
            if (String(users[i].id) === String(user.id)) { record = users[i]; break; }
        }
        if (!record) {
            record = {
                id: user.id,
                name: user.name || user.fullName || '',
                email: user.email,
                password: 'password123',
                roles: user.roles || [LearnovaConstants.ROLES.STUDENT],
                status: user.status || LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
                joined: new Date().toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
            };
            users.push(record);
        }

        var first = (body && body.firstName) || null;
        var last = (body && body.lastName) || null;
        var firstName = first == null || String(first).trim() === '' ? null : String(first).trim();
        var lastName = last == null || String(last).trim() === '' ? null : String(last).trim();

        if (firstName != null || lastName != null) {
            var oldName = (record.name || '').split(/\s+/);
            var newFirst = firstName != null ? firstName : (oldName[0] || '');
            var newLast = lastName != null ? lastName : (oldName.slice(1).join(' ') || '');
            record.name = (newFirst + ' ' + newLast).trim();
        }

        var newPassword = (body && body.newPassword) || null;
        if (newPassword != null && String(newPassword).length) {
            if (String(newPassword).length < 8) {
                fail('New password must be at least 8 characters.');
            }
            var currentPassword = (body && body.currentPassword) || '';
            if (currentPassword !== record.password) {
                fail('Current password is incorrect.', 401);
            }
            record.password = String(newPassword);
        }

        writeJSON(USERS_KEY, users);

        var updated = profileOf(record);
        var session = Object.assign({}, currentUser(), {
            name: updated.fullName,
            fullName: updated.fullName,
            email: updated.email,
            roles: updated.roles,
            role: updated.role,
            status: updated.status
        });
        LearnovaSession.set(session);
        return updated;
    }

    /* ---------- Auth ---------- */

    function authLogin(body) {
        var email = String((body && body.email) || '').trim().toLowerCase();
        var password = body && body.password;
        var users = readJSON(USERS_KEY, []);
        var user = null;
        for (var i = 0; i < users.length; i++) {
            if (String(users[i].email || '').toLowerCase() === email) { user = users[i]; break; }
        }
        if (!user || user.password !== password) {
            fail('Invalid email or password.');
        }
        if (user.status === LearnovaConstants.ACCOUNT_STATUS.SUSPENDED ||
            user.status === LearnovaConstants.ACCOUNT_STATUS.BANNED) {
            fail('This account is ' + user.status + '. ' +
                (user.status === 'suspended' ? 'Please contact support.' : 'Contact an administrator.'));
        }
        var roles = Array.isArray(user.roles) && user.roles.length
            ? user.roles
            : (user.role ? [user.role] : [LearnovaConstants.ROLES.STUDENT]);
        return {
            id: user.id,
            name: user.name,
            email: user.email,
            roles: roles,
            role: roles[0],
            status: user.status || LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
            token: 'demo-token-' + user.id
        };
    }

    function authRegister(body) {
        var name = String(
            (body && (body.name || body.fullName)) ||
            (
                body && (body.firstName || body.lastName)
                    ? ((body.firstName || '') + ' ' + (body.lastName || '')).trim()
                    : ''
            )
        ).trim();
        var email = String((body && body.email) || '').trim().toLowerCase();
        var password = body && body.password;
        if (!name) fail('Please fill in your name.');
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail('Please enter a valid email address.');
        if (String(password || '').length < 8) fail('Password must be at least 8 characters.');
        var users = readJSON(USERS_KEY, []);
        for (var i = 0; i < users.length; i++) {
            if (String(users[i].email || '').toLowerCase() === email) {
                fail('An account with this email already exists.');
            }
        }
        var user = {
            id: users.reduce(function (max, u) { return Math.max(max, Number(u.id) || 0); }, 0) + 1,
            name: name,
            email: email,
            password: password,
            roles: [LearnovaConstants.ROLES.STUDENT],
            status: LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
            joined: new Date().toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
        };
        users.push(user);
        writeJSON(USERS_KEY, users);
        return {
            id: user.id,
            name: user.name,
            email: user.email,
            roles: user.roles,
            role: user.roles[0],
            status: user.status
        };
    }

    /* ---------- Admin ---------- */

    function requireAdmin() {
        if (!hasRole(LearnovaConstants.ROLES.ADMIN)) fail('Admin access required.', 403);
    }

    function stripPassword(user) {
        var out = Object.assign({}, user);
        delete out.password;
        return out;
    }

    function findUserById(users, id) {
        for (var i = 0; i < users.length; i++) {
            if (String(users[i].id) === String(id)) return users[i];
        }
        return null;
    }

    function findRequestById(requests, id) {
        for (var i = 0; i < requests.length; i++) {
            if (String(requests[i].id) === String(id)) return requests[i];
        }
        return null;
    }

    function adminListUsers() {
        return readJSON(USERS_KEY, []).map(stripPassword);
    }

    function adminCreateUser(body) {
        var name = String((body && body.name) || '').trim();
        var email = String((body && body.email) || '').trim().toLowerCase();
        var password = body && body.password;
        var role = (body && body.role) || LearnovaConstants.ROLES.STUDENT;
        if (!name) fail('Please fill in the user\'s name.');
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail('Please enter a valid email address.');
        if (String(password || '').length < 8) fail('Password must be at least 8 characters.');
        var users = readJSON(USERS_KEY, []);
        for (var ci = 0; ci < users.length; ci++) {
            if (String(users[ci].email || '').toLowerCase() === email) {
                fail('An account with this email already exists.');
            }
        }
        var user = {
            id: users.reduce(function (max, u) { return Math.max(max, Number(u.id) || 0); }, 0) + 1,
            name: name,
            email: email,
            password: password,
            roles: [role],
            role: role,
            status: LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
            joined: new Date().toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
        };
        users.push(user);
        writeJSON(USERS_KEY, users);
        return stripPassword(user);
    }

    function adminStats() {
        var users = readJSON(USERS_KEY, []);
        var courses = readCourses();
        var instructors = users.filter(function (u) {
            var roles = Array.isArray(u.roles) && u.roles.length ? u.roles : (u.role ? [u.role] : []);
            return roles.indexOf(LearnovaConstants.ROLES.INSTRUCTOR) !== -1;
        }).length;
        var activeCourses = courses.filter(function (c) {
            return c.status === COURSE_STATUS.PUBLISHED;
        }).length;
        var enrollments = 0;
        for (var i = 0; i < localStorage.length; i++) {
            if ((localStorage.key(i) || '').indexOf('learnova_enrolled_') === 0) enrollments++;
        }
        return {
            users: users.length,
            instructors: instructors,
            activeCourses: activeCourses,
            enrollments: enrollments
        };
    }

    function adminSetRole(id, body) {
        var users = readJSON(USERS_KEY, []);
        var user = findUserById(users, id);
        if (!user) fail('User not found.', 404);
        var role = body && body.role;
        if (!role) fail('Role is required.');
        user.roles = [role];
        user.role = role;
        writeJSON(USERS_KEY, users);
        return stripPassword(user);
    }

    function adminSetStatus(id, body) {
        var users = readJSON(USERS_KEY, []);
        var user = findUserById(users, id);
        if (!user) fail('User not found.', 404);
        var status = body && body.status;
        if (!status) fail('Status is required.');
        user.status = status;
        writeJSON(USERS_KEY, users);
        return stripPassword(user);
    }

    function adminDeleteUser(id) {
        var users = readJSON(USERS_KEY, []);
        var next = users.filter(function (u) { return String(u.id) !== String(id); });
        if (next.length === users.length) fail('User not found.', 404);
        writeJSON(USERS_KEY, next);
        return { ok: true };
    }

    function adminRoles() {
        return [
            LearnovaConstants.ROLES.STUDENT,
            LearnovaConstants.ROLES.INSTRUCTOR,
            LearnovaConstants.ROLES.ADMIN
        ].map(function (name) { return { name: name }; });
    }

    function adminApproveRequest(id) {
        var requests = readJSON(REQUESTS_KEY, []);
        var req = findRequestById(requests, id);
        if (!req) fail('Request not found.', 404);
        req.status = REQ_STATUS.APPROVED;
        writeJSON(REQUESTS_KEY, requests);

        var users = readJSON(USERS_KEY, []);
        var user = findUserById(users, req.email);
        if (!user) {
            var byEmail = null;
            for (var i = 0; i < users.length; i++) {
                if (users[i].email === req.email) { byEmail = users[i]; break; }
            }
            user = byEmail;
        }
        if (!user) {
            user = {
                id: users.reduce(function (max, u) { return Math.max(max, Number(u.id) || 0); }, 0) + 1,
                name: req.name,
                email: req.email,
                password: 'password123',
                roles: [LearnovaConstants.ROLES.STUDENT],
                status: LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
                joined: new Date().toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
            };
            users.push(user);
        }
        if (user.roles.indexOf(LearnovaConstants.ROLES.INSTRUCTOR) === -1) {
            user.roles.push(LearnovaConstants.ROLES.INSTRUCTOR);
        }
        writeJSON(USERS_KEY, users);
        pushNotification(req.email, 'Your instructor request was approved. You can now create courses.');
        return req;
    }

    function adminRejectRequest(id) {
        var requests = readJSON(REQUESTS_KEY, []);
        var req = findRequestById(requests, id);
        if (!req) fail('Request not found.', 404);
        req.status = REQ_STATUS.REJECTED;
        writeJSON(REQUESTS_KEY, requests);
        pushNotification(req.email, 'Your instructor request was rejected by an admin.');
        return req;
    }

    function adminPublishCourse(id) {
        var courses = readCourses();
        var idx = indexOfCourse(courses, id);
        if (idx === -1) fail('Course not found.', 404);
        courses[idx].status = COURSE_STATUS.PUBLISHED;
        writeCourses(courses);
        if (courses[idx].instructorEmail) {
            pushNotification(courses[idx].instructorEmail, 'Your course "' + courses[idx].title + '" was published. Students can now enroll.');
        }
        return courses[idx];
    }

    /* ---------- Dispatch ---------- */

    function parseBody(raw) {
        if (raw == null) return {};
        if (typeof raw === 'string' && raw.length) {
            try { return JSON.parse(raw); } catch (e) { return {}; }
        }
        return raw;
    }

    function parseQuery(str) {
        var out = {};
        String(str || '').split('&').forEach(function (pair) {
            if (!pair) return;
            var idx = pair.indexOf('=');
            var key = idx >= 0 ? pair.slice(0, idx) : pair;
            var val = idx >= 0 ? decodeURIComponent(pair.slice(idx + 1)) : '';
            out[key] = val;
        });
        return out;
    }

    function routeMatch(parts, pattern) {
        if (parts.length !== pattern.length) return null;
        var params = {};
        for (var i = 0; i < pattern.length; i++) {
            var expected = pattern[i];
            if (expected.charAt(0) === ':') {
                params[expected.slice(1)] = decodeURIComponent(parts[i]);
            } else if (expected !== parts[i]) {
                return null;
            }
        }
        return params;
    }

    function dispatch(method, parts, body, query) {
        var p, course;

        /* ---- Auth ---- */
        p = routeMatch(parts, ['auth', 'login']);
        if (p && method === 'POST') return authLogin(body);
        p = routeMatch(parts, ['auth', 'register']);
        if (p && method === 'POST') return authRegister(body);
        p = routeMatch(parts, ['auth', 'logout']);
        if (p && method === 'POST') return { ok: true };

        /* ---- Users / profile ---- */
        p = routeMatch(parts, ['users', 'me']);
        if (p) {
            if (method === 'GET') return myProfile();
            if (method === 'PUT') return updateMyProfile(body);
        }

        /* ---- Courses ---- */
        p = routeMatch(parts, ['courses']);
        if (p && method === 'GET') return readCourses();
        if (p && method === 'POST') return courseCreate(body);

        p = routeMatch(parts, ['courses', ':id', 'curriculum']);
        if (p) {
            if (method === 'GET') return readCurriculum(p.id);
            if (method === 'PUT') return writeCurriculum(p.id, body);
        }

        p = routeMatch(parts, ['courses', ':id', 'lessons', ':lesson']);
        if (p) {
            if (method === 'GET') {
                return readLessonContent(slugify(p.lesson)) || { title: '', description: '', blocks: [] };
            }
            if (method === 'PUT') return writeLessonContent(slugify(p.lesson), body);
        }

        p = routeMatch(parts, ['courses', ':id', 'prerequisites']);
        if (p) {
            if (method === 'GET') return getPrerequisites(p.id);
            if (method === 'PUT') return setPrerequisites(p.id, body);
        }

        p = routeMatch(parts, ['courses', ':id', 'reviews']);
        if (p) {
            if (method === 'GET') return listReviews(p.id);
            if (method === 'POST') return createReview(p.id, body);
        }

        p = routeMatch(parts, ['courses', ':id']);
        if (p) {
            course = findCourse(p.id);
            if (!course) fail('Course not found.', 404);
            if (method === 'GET') return enrichCourse(course);
            if (method === 'PUT') return courseUpdate(p.id, body);
            if (method === 'DELETE') return courseRemove(p.id);
        }

        /* ---- Enrollments (backend REST contract) ---- */
        p = routeMatch(parts, ['enrollments', 'courses', ':courseId']);
        if (p && method === 'POST') return enrollCourse(p.courseId);
        p = routeMatch(parts, ['enrollments', 'tracks', ':trackId']);
        if (p && method === 'POST') return enrollTrack(p.trackId);
        p = routeMatch(parts, ['enrollments', 'my-courses']);
        if (p && method === 'GET') return myCourseEnrollments();
        p = routeMatch(parts, ['enrollments', 'my-tracks']);
        if (p && method === 'GET') return myTrackEnrollments();
        p = routeMatch(parts, ['enrollments', 'courses', ':courseId', 'access']);
        if (p && method === 'GET') return courseAccess(p.courseId);
        p = routeMatch(parts, ['enrollments', 'stats']);
        if (p && method === 'GET') return enrollmentStats();

        /* ---- Progress ---- */
        p = routeMatch(parts, ['progress', 'mine']);
        if (p && method === 'GET') return myEnrollments();
        p = routeMatch(parts, ['progress', ':courseId', 'lessons', ':lesson', 'quiz']);
        if (p && method === 'POST') return submitQuizAttempt(p.courseId, p.lesson, body);
        p = routeMatch(parts, ['progress', ':courseId', 'lessons', ':lesson']);
        if (p && method === 'PUT') {
            localStorage.setItem('learnova_lesson_viewed_' + slugify(p.lesson), '1');
            return { ok: true };
        }

        /* ---- Quizzes ---- */
        p = routeMatch(parts, ['quizzes', 'lesson', ':lesson', 'status']);
        if (p && method === 'GET') return quizStatus(slugify(p.lesson), query.bypass === '1');
        p = routeMatch(parts, ['quizzes', 'lesson', ':lesson', 'random']);
        if (p && method === 'GET') {
            var n = Number(query.count) || QUIZ.RANDOM_PER_STUDENT;
            return shuffle(ensureBank(slugify(p.lesson)).slice()).slice(0, n).map(function (q) {
                return { id: q.id, text: q.text, options: q.options };
            });
        }
        p = routeMatch(parts, ['quizzes', 'lesson', ':lesson']);
        if (p) {
            if (method === 'GET') return ensureBank(slugify(p.lesson));
            if (method === 'POST') {
                var bank = ensureBank(slugify(p.lesson));
                var nextId = bank.reduce(function (max, q) { return Math.max(max, q.id); }, 0) + 1;
                var question = {
                    id: nextId,
                    text: body.text,
                    options: body.options || [],
                    correct: body.correct || 'A'
                };
                bank.push(question);
                writeBank(slugify(p.lesson), bank);
                return question;
            }
        }
        p = routeMatch(parts, ['quizzes', ':id']);
        if (p) {
            var banks = allBanks();
            if (method === 'GET') {
                for (var bi = 0; bi < banks.length; bi++) {
                    var q = findQuestion(banks[bi].questions, p.id);
                    if (q) return q;
                }
                fail('Question not found.', 404);
            }
            if (method === 'PUT') {
                for (var ui = 0; ui < banks.length; ui++) {
                    var uq = findQuestion(banks[ui].questions, p.id);
                    if (uq) {
                        Object.keys(body).forEach(function (k) { if (k !== 'id') uq[k] = body[k]; });
                        localStorage.setItem(banks[ui].key, JSON.stringify(banks[ui].questions));
                        return uq;
                    }
                }
                fail('Question not found.', 404);
            }
            if (method === 'DELETE') {
                for (var di = 0; di < banks.length; di++) {
                    var diq = -1;
                    for (var dj = 0; dj < banks[di].questions.length; dj++) {
                        if (String(banks[di].questions[dj].id) === String(p.id)) { diq = dj; break; }
                    }
                    if (diq !== -1) {
                        banks[di].questions.splice(diq, 1);
                        localStorage.setItem(banks[di].key, JSON.stringify(banks[di].questions));
                        return { ok: true };
                    }
                }
                fail('Question not found.', 404);
            }
        }

        /* ---- Certificates ---- */
        p = routeMatch(parts, ['certificates', 'mine']);
        if (p && method === 'GET') return myCertificates();
        p = routeMatch(parts, ['certificates']);
        if (p && method === 'POST') return generateCertificate(body);

        /* ---- Notifications ---- */
        p = routeMatch(parts, ['notifications']);
        if (p) {
            if (method === 'GET') {
                var user = currentUser();
                var items = readJSON(NOTIFICATIONS_KEY, []);
                if (user && user.email) {
                    return items.filter(function (n) { return !n.email || n.email === user.email; });
                }
                return items;
            }
            if (method === 'POST') {
                pushNotification((body && body.message) || '', (body && body.email) || '');
                return { ok: true };
            }
        }
        p = routeMatch(parts, ['notifications', ':id', 'read']);
        if (p && method === 'PUT') {
            var all = readJSON(NOTIFICATIONS_KEY, []);
            var found = null;
            for (var ni = 0; ni < all.length; ni++) {
                if (String(all[ni].id) === String(p.id)) { all[ni].is_read = true; found = all[ni]; break; }
            }
            writeJSON(NOTIFICATIONS_KEY, all);
            if (!found) fail('Notification not found.', 404);
            return found;
        }

        /* ---- Instructor requests ---- */
        p = routeMatch(parts, ['instructor-requests', 'mine']);
        if (p && method === 'GET') return myInstructorRequest();
        p = routeMatch(parts, ['instructor-requests']);
        if (p && method === 'POST') return createInstructorRequest(body);

        /* ---- Admin ---- */
        if (parts[0] === 'admin') {
            requireAdmin();
            var ap, user;

            ap = routeMatch(parts, ['admin', 'users']);
            if (ap) {
                if (method === 'GET') return adminListUsers();
                if (method === 'POST') return adminCreateUser(body);
            }

            ap = routeMatch(parts, ['admin', 'stats']);
            if (ap && method === 'GET') return adminStats();

            ap = routeMatch(parts, ['admin', 'users', ':id', 'role']);
            if (ap && method === 'PUT') return adminSetRole(ap.id, body);

            ap = routeMatch(parts, ['admin', 'users', ':id', 'status']);
            if (ap && method === 'PUT') return adminSetStatus(ap.id, body);

            ap = routeMatch(parts, ['admin', 'users', ':id']);
            if (ap && method === 'DELETE') return adminDeleteUser(ap.id);

            ap = routeMatch(parts, ['admin', 'roles']);
            if (ap && method === 'GET') return adminRoles();

            ap = routeMatch(parts, ['admin', 'instructor-requests']);
            if (ap && method === 'GET') return readJSON(REQUESTS_KEY, []);

            ap = routeMatch(parts, ['admin', 'instructor-requests', ':id', 'approve']);
            if (ap && method === 'POST') return adminApproveRequest(ap.id);

            ap = routeMatch(parts, ['admin', 'instructor-requests', ':id', 'reject']);
            if (ap && method === 'POST') return adminRejectRequest(ap.id);

            ap = routeMatch(parts, ['admin', 'courses']);
            if (ap && method === 'GET') return readCourses();

            ap = routeMatch(parts, ['admin', 'courses', ':id', 'publish']);
            if (ap && method === 'POST') return adminPublishCourse(ap.id);

            fail('Mock: unknown admin endpoint /' + parts.join('/'), 404);
        }

        fail('Mock: unknown endpoint ' + method + ' /' + parts.join('/'), 404);
    }

    /* ---------- Public entry point ---------- */

    function handleRequest(method, path, rawBody) {
        ensureSeed();
        var body = parseBody(rawBody);
        var strPath = String(path || '');
        var qIndex = strPath.indexOf('?');
        var pathOnly = qIndex >= 0 ? strPath.slice(0, qIndex) : strPath;
        var query = qIndex >= 0 ? parseQuery(strPath.slice(qIndex + 1)) : {};
        var parts = pathOnly.split('/').filter(Boolean);

        return Promise.resolve().then(function () {
            return dispatch(method, parts, body, query);
        });
    }

    return {
        handleRequest: handleRequest,
        isMockSession: isMockSession
    };
})();
