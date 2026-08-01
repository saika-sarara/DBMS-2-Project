/* ==========================================================================
   Course Detail page (course-detail.html)
   Implements the student-facing course flows from the spec:
   - Enrollment only when ALL prerequisites are satisfied (AND logic, spec 3.1);
     missing prerequisites offer a Bypass Exam (spec 3.3).
   - Track enrollment option for track courses (spec 4.2).
   - Sequential lesson unlocking: the first lesson is open; each next lesson
     unlocks only after the previous lesson's quiz is passed (spec 4.3).
   - Course completion -> auto-issued certificate with an LRV-XXXX-XXXX code
     (spec 8), which then unlocks the review form (spec 7).
   - Reviews: one per student, 1-5 stars, no edits or deletions.
   ========================================================================== */
(function () {
    'use strict';

    var CERT = LearnovaConstants.CERTIFICATE;

    /* ---------- Course registry (slug -> course) ---------- */
    var LESSONS = [
        'Introduction to Databases', 'SQL Basics', 'Installing Your Tools',
        'SELECT Statements', 'Filtering with WHERE', 'Sorting and Limiting',
        'Joins Overview', 'One-to-Many Relationships', 'Foreign Keys in Action',
        'Indexes Explained', 'Query Tuning', 'Final Assessment'
    ];

    var COURSES = {
        'database-design': {
            title: 'Database Design Fundamentals',
            author: 'By Dr. Alex Chen',
            track: 'Database Engineer',
            prereqs: [
                { slug: 'sql-fundamentals', title: 'SQL Fundamentals' },
                { slug: 'data-modeling-basics', title: 'Data Modeling Basics' }
            ],
            trackCourses: [
                'SQL Fundamentals', 'Advanced SQL & Optimization',
                'Graph Databases (Neo4j)', 'Data Warehousing & ETL'
            ]
        }
    };

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    /* ---------- Tiny storage helpers ---------- */
    function getFlag(key) { return localStorage.getItem(key) === '1'; }
    function setFlag(key) { localStorage.setItem(key, '1'); }

    function pushNotification(message) {
        var key = LearnovaConstants.NOTIFICATIONS_KEY;
        var items = [];
        try { items = JSON.parse(localStorage.getItem(key) || '[]'); } catch (e) { items = []; }
        items.unshift({
            id: Date.now(),
            message: message,
            is_read: false,
            created_at: new Date().toISOString()
        });
        localStorage.setItem(key, JSON.stringify(items.slice(0, 20)));
    }

    function certCode() {
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

    function courseCompleted(courseSlug) {
        return getFlag('learnova_course_complete_' + courseSlug);
    }

    function prereqSatisfied(prereq) {
        /* Completed the prerequisite course OR cleared it via a bypass exam. */
        return getFlag('learnova_course_complete_' + prereq.slug) ||
            getFlag('learnova_bypass_pass_' + prereq.slug);
    }

    /* ---------- Page setup ---------- */
    var params = new URLSearchParams(window.location.search);
    var courseKey = params.get('course') || 'database-design';
    var course = COURSES[courseKey] || {
        title: (params.get('course') || 'Database Design Fundamentals').replace(/-/g, ' '),
        author: 'By Dr. Alex Chen',
        track: 'Database Engineer',
        prereqs: [],
        trackCourses: []
    };
    var ENROLL_KEY = 'learnova_enrolled_' + courseKey;

    function el(id) { return document.getElementById(id); }

    function setTitle() {
        var titleEl = el('courseTitle');
        if (titleEl) titleEl.textContent = course.title;
    }

    /* ---------- Enrollment ---------- */
    function refreshEnrollState() {
        var btn = el('enrollBtn');
        if (!btn) return;
        if (getFlag(ENROLL_KEY)) {
            btn.textContent = 'Continue Learning';
            btn.classList.add('enrolled');
            var msg = el('enrollMessage');
            if (msg) msg.innerHTML = '<p class="flow-note success">You are enrolled. The first lesson is unlocked — complete each quiz (≥60%) to unlock the next.</p>';
            var trackBtn = el('trackEnrollBtn');
            if (trackBtn && course.track) {
                trackBtn.style.display = '';
            }
        } else {
            btn.textContent = 'Enroll Now';
            btn.classList.remove('enrolled');
        }
    }

    function renderPrereqNotice() {
        var box = el('prereqNotice');
        if (!box) return;
        if (getFlag(ENROLL_KEY)) { box.innerHTML = ''; return; }

        if (!course.prereqs.length) { box.innerHTML = ''; return; }

        var missing = course.prereqs.filter(function (p) { return !prereqSatisfied(p); });
        if (!missing.length) { box.innerHTML = ''; return; }

        var list = missing.map(function (p) {
            return '<li>' +
                '<span>' + p.title + '</span>' +
                '<a class="btn btn-outline btn-sm" href="quiz-attempt.html?bypass=1&lesson=' +
                    encodeURIComponent(p.title) + '">Attempt Bypass Exam</a>' +
            '</li>';
        }).join('');

        box.innerHTML =
            '<div class="prereq-banner">' +
                '<strong>Prerequisites required (AND logic):</strong> complete all listed courses with ≥60%, or pass a Bypass Exam per missing course to unlock enrollment.' +
                '<ul>' + list + '</ul>' +
            '</div>';
    }

    function tryEnroll() {
        if (getFlag(ENROLL_KEY)) {
            window.location.href = 'quiz-attempt.html?lesson=' + encodeURIComponent(LESSONS[0]);
            return;
        }

        var missing = course.prereqs.filter(function (p) { return !prereqSatisfied(p); });
        if (missing.length) {
            renderPrereqNotice();
            var msg = el('enrollMessage');
            if (msg) {
                msg.innerHTML = '<p class="flow-note warn">Enrollment blocked. ' +
                    'Finish the missing prerequisite(s) above, or pass their Bypass Exams first.</p>';
            }
            el('prereqNotice').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            return;
        }

        setFlag(ENROLL_KEY);
        pushNotification('You enrolled in "' + course.title + '". The first lesson is unlocked.');
        refreshEnrollState();
        renderPrereqNotice();
        applyLessonLocks();
        var m = el('enrollMessage');
        if (m) {
            m.innerHTML = '<p class="flow-note success">Enrolled! The first lesson is unlocked. ' +
                (course.track ? 'You can also enroll in the full "' + course.track + '" track below.' : '') + '</p>';
        }
    }

    function enrollTrack() {
        if (!course.track) return;
        var trackSlug = slugify(course.track);
        setFlag('learnova_track_enrolled_' + trackSlug);
        course.trackCourses.forEach(function (name) {
            setFlag('learnova_enrolled_' + slugify(name));
        });
        pushNotification('You joined the "' + course.track + '" track. All its courses were added; locked ones need their prerequisites.');
        alert('You are now enrolled in the "' + course.track + '" track. All courses in the track were added — course content stays locked until prerequisites are satisfied.');
        var trackBtn = el('trackEnrollBtn');
        if (trackBtn) trackBtn.style.display = 'none';
    }

    /* ---------- Sequential lesson unlocking (spec 4.3) ---------- */
    function applyLessonLocks() {
        var rows = document.querySelectorAll('.lesson-row');
        var enrolled = getFlag(ENROLL_KEY);
        var prevPassed = false;

        rows.forEach(function (row, i) {
            var lessonName = row.getAttribute('data-lesson') || '';
            var slug = slugify(lessonName);
            var unlocked = false;

            if (i === 0) {
                unlocked = true;
            } else if (enrolled && prevPassed) {
                unlocked = true;
            } else if (getFlag('learnova_quiz_pass_' + slug)) {
                unlocked = true;
            }

            if (unlocked) {
                row.classList.remove('locked');
                row.querySelector('.lesson-icon').innerHTML = '<i class="fa-solid fa-circle-play"></i>';
                row.removeAttribute('title');
            } else {
                row.classList.add('locked');
                row.querySelector('.lesson-icon').innerHTML = '<i class="fa-solid fa-lock"></i>';
                row.setAttribute('title', 'Complete the previous lesson\'s quiz (≥60%) to unlock.');
            }

            prevPassed = getFlag('learnova_quiz_pass_' + slug);
        });

        /* Update the "completed lessons" counter in the curriculum heading. */
        var done = LESSONS.filter(function (name) {
            return getFlag('learnova_quiz_pass_' + slugify(name));
        }).length;
        var badge = document.querySelector('.section-heading .track-badge');
        if (badge) badge.textContent = '4 Modules · 12 Lessons · ' + done + ' completed';
    }

    /* ---------- Completion & certificate (spec 5.5 / 8) ---------- */
    function applyCompletion() {
        if (!getFlag(ENROLL_KEY)) return;

        var done = LESSONS.filter(function (name) {
            return getFlag('learnova_quiz_pass_' + slugify(name));
        }).length;
        if (done < LESSONS.length) return;

        if (!courseCompleted(courseKey)) {
            setFlag('learnova_course_complete_' + courseKey);
            var code = certCode();
            localStorage.setItem('learnova_cert_code_' + courseKey, code);
            pushNotification('Course completed! Your certificate (' + code + ') has been issued.');
        }

        var banner = el('completionBanner');
        if (banner) {
            var existingCode = localStorage.getItem('learnova_cert_code_' + courseKey) || certCode();
            banner.innerHTML =
                '<div class="certificate-banner">' +
                    '<div class="certificate-kicker">Course Certificate</div>' +
                    '<div class="certificate-title">' + course.title + '</div>' +
                    '<div class="certificate-code">' + existingCode + '</div>' +
                    '<p>Issued automatically on completion. Verify any code via the public certificate lookup.</p>' +
                '</div>';
        }
        setupReview(true);
    }

    /* ---------- Reviews (spec 7) ---------- */
    function setupReview(completed) {
        var stars = document.querySelectorAll('.review-star');
        var textarea = el('reviewText');
        var submitBtn = el('submitReviewBtn');
        var note = el('reviewNote');
        var message = el('reviewMessage');
        var REVIEW_KEY = 'learnova_review_' + courseKey;
        var rating = 0;

        if (localStorage.getItem(REVIEW_KEY)) {
            if (note) note.textContent = 'Your review has been submitted. Per platform rules it cannot be edited or deleted.';
            stars.forEach(function (s) { s.classList.add('disabled'); });
            if (textarea) textarea.disabled = true;
            if (submitBtn) submitBtn.disabled = true;
            if (message) message.innerHTML = '<p class="flow-note success">Thank you for your review!</p>';
            return;
        }

        if (!completed) {
            if (note) note.textContent = 'Reviews are available once you complete this course (one review per student).';
            stars.forEach(function (s) { s.classList.add('disabled'); });
            if (textarea) textarea.disabled = true;
            if (submitBtn) submitBtn.disabled = true;
            return;
        }

        if (note) note.textContent = 'Rate your experience from 1 to 5 stars. Submissions cannot be edited or deleted.';

        stars.forEach(function (s) {
            s.classList.remove('disabled');
            s.addEventListener('click', function () {
                rating = Number(s.getAttribute('data-value'));
                stars.forEach(function (o) {
                    o.classList.toggle('active', Number(o.getAttribute('data-value')) <= rating);
                });
            });
        });

        submitBtn.addEventListener('click', function () {
            if (rating < 1) {
                alert('Please select a star rating (1-5) before submitting.');
                return;
            }
            var comment = textarea.value.trim();
            localStorage.setItem(REVIEW_KEY, JSON.stringify({ rating: rating, comment: comment, at: new Date().toISOString() }));
            pushNotification('You reviewed "' + course.title + '" with ' + rating + ' stars.');
            if (message) message.innerHTML = '<p class="flow-note success">Review submitted (rating ' + rating + '/5). It cannot be edited or deleted.</p>';
            stars.forEach(function (s) { s.classList.add('disabled'); });
            textarea.disabled = true;
            submitBtn.disabled = true;
        });
    }

    /* ---------- Wire-up ---------- */
    document.addEventListener('DOMContentLoaded', function () {
        setTitle();
        refreshEnrollState();
        renderPrereqNotice();
        applyLessonLocks();
        applyCompletion();

        var enrollBtn = el('enrollBtn');
        if (enrollBtn) enrollBtn.addEventListener('click', tryEnroll);

        var trackBtn = el('trackEnrollBtn');
        if (trackBtn) trackBtn.addEventListener('click', enrollTrack);

        /* Locked lesson rows must not navigate. */
        document.addEventListener('click', function (event) {
            var row = event.target.closest('.lesson-row.locked');
            if (row) {
                event.preventDefault();
                alert('This lesson is locked. Complete the previous lesson\'s quiz (≥60%) to unlock it.');
            }
        });

        if (!courseCompleted(courseKey)) {
            setupReview(false);
        }
    });
})();
