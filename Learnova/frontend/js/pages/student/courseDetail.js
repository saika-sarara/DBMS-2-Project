/* ==========================================================================
   Course Detail page (course-detail.html)
   Data-driven: course info comes from the saved course registry and its
   saved curriculum (built by the instructor). No hardcoded demo content.
   - Enrollment only when ALL prerequisites are satisfied (AND logic, spec 3.1);
     missing prerequisites offer a Bypass Exam (spec 3.3).
   - Sequential lesson unlocking: the first lesson is open; each next lesson
     unlocks only after the previous lesson's quiz is passed (spec 4.3).
   - Lessons open into lesson-view.html (YouTube / notes / links).
   - Course completion -> auto-issued certificate (LRV-XXXX-XXXX) and the
     review form (spec 7) unlocks.
   ========================================================================== */
(function () {
    'use strict';

    var CERT = LearnovaConstants.CERTIFICATE;
    var COURSES_KEY = LearnovaConstants.COURSES_KEY;
    var NOTIFICATIONS_KEY = LearnovaConstants.NOTIFICATIONS_KEY;

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    /* ---------- Tiny storage helpers ---------- */
    function getFlag(key) { return localStorage.getItem(key) === '1'; }
    function setFlag(key) { localStorage.setItem(key, '1'); }

    function pushNotification(message) {
        var items = [];
        try { items = JSON.parse(localStorage.getItem(NOTIFICATIONS_KEY) || '[]'); } catch (e) { items = []; }
        items.unshift({
            id: Date.now(),
            message: message,
            is_read: false,
            created_at: new Date().toISOString()
        });
        localStorage.setItem(NOTIFICATIONS_KEY, JSON.stringify(items.slice(0, 20)));
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
        return getFlag('learnova_course_complete_' + prereq.slug) ||
            getFlag('learnova_bypass_pass_' + prereq.slug);
    }

    /* ---------- Load course + curriculum ---------- */
    var params = new URLSearchParams(window.location.search);
    var courseKey = params.get('course') || 'database-design';
    var ENROLL_KEY = 'learnova_enrolled_' + courseKey;

    var course = null;
    try {
        var courses = JSON.parse(localStorage.getItem(COURSES_KEY) || '[]');
        course = courses.filter(function (c) { return c.slug === courseKey; })[0] || null;
    } catch (e) { course = null; }

    var curriculum = null;
    try {
        var raw = JSON.parse(localStorage.getItem('learnova_curriculum_' + courseKey) || 'null');
        if (raw && Array.isArray(raw.modules)) curriculum = raw;
    } catch (e) { curriculum = null; }

    var LESSONS = [];
    if (curriculum) {
        curriculum.modules.forEach(function (m) {
            (m.lessons || []).forEach(function (l) { LESSONS.push(l.name); });
        });
    }

    var PREREQS = (course && course.prereqs) ? course.prereqs : [];
    var TRACK = course ? course.track : null;
    var TRACK_COURSES = (course && course.trackCourses) ? course.trackCourses : [];

    function el(id) { return document.getElementById(id); }

    function setHero() {
        var title = course ? course.title : (courseKey.replace(/-/g, ' ').replace(/\b\w/g, function (c) { return c.toUpperCase(); }));
        var t = el('courseTitle');
        if (t) t.textContent = title;
        var sub = el('courseSubtitle');
        if (sub) sub.textContent = (course && course.description) ? course.description : 'This course hasn\'t been published yet. Check back soon for content.';
        var tag = el('courseTrackTag');
        if (tag) tag.textContent = (course && course.track) ? course.track : 'Course';

        var meta = el('courseMeta');
        if (meta) {
            if (curriculum) {
                var lessons = LESSONS.length;
                var modules = curriculum.modules.length;
                meta.style.display = '';
                meta.innerHTML =
                    '<span class="meta-item"><i class="fa-regular fa-folder-open"></i> ' + modules + ' Modules</span>' +
                    '<span class="meta-item"><i class="fa-regular fa-file-lines"></i> ' + lessons + ' Lessons</span>';
            } else {
                meta.style.display = 'none';
            }
        }
    }

    /* ---------- Curriculum rendering ---------- */
    function renderCurriculum() {
        var box = el('curriculumContainer');
        var count = el('curriculumCount');
        if (!box) return;

        if (!curriculum || LESSONS.length === 0) {
            box.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-box-open"></i></div>' +
                    '<h3>No curriculum yet</h3>' +
                    '<p>The instructor hasn\'t published lessons for this course. Course content will appear here once it is ready.</p>' +
                '</div>';
            if (count) count.textContent = '0 Lessons';
            return;
        }

        if (count) count.textContent = curriculum.modules.length + ' Modules · ' + LESSONS.length + ' Lessons';

        box.innerHTML = curriculum.modules.map(function (module) {
            var lessonsHtml = (module.lessons || []).map(function (lesson) {
                var slug = slugify(lesson.name);
                return '<a class="lesson-row" href="lesson-view.html?course=' + encodeURIComponent(courseKey) +
                        '&lesson=' + encodeURIComponent(lesson.name) + '" data-lesson="' +
                        lesson.name.replace(/"/g, '&quot;') + '">' +
                    '<span class="lesson-icon"><i class="fa-solid fa-circle-play"></i></span>' +
                    '<span class="lesson-row-name">' + lesson.name + '</span>' +
                    '<span class="lesson-quiz-pill">Lesson</span>' +
                '</a>';
            }).join('');

            return '<details class="module-item" open>' +
                '<summary>' +
                    '<span class="module-title-lg">' + module.title + '</span>' +
                    '<span class="module-count">' + (module.lessons || []).length + ' Lessons</span>' +
                '</summary>' +
                '<div class="module-lesson-list">' + lessonsHtml + '</div>' +
            '</details>';
        }).join('');
    }

    /* ---------- Enrollment ---------- */
    function firstLessonUrl() {
        if (LESSONS.length === 0) return null;
        return 'lesson-view.html?course=' + encodeURIComponent(courseKey) +
            '&lesson=' + encodeURIComponent(LESSONS[0]);
    }

    function refreshEnrollState() {
        var btn = el('enrollBtn');
        if (!btn) return;
        if (getFlag(ENROLL_KEY)) {
            btn.textContent = 'Continue Learning';
            btn.classList.add('enrolled');
            var msg = el('enrollMessage');
            if (msg) msg.innerHTML = '<p class="flow-note success">You are enrolled. The first lesson is unlocked — complete each quiz (≥60%) to unlock the next.</p>';
            var trackBtn = el('trackEnrollBtn');
            if (trackBtn && TRACK) trackBtn.style.display = '';
        } else {
            btn.textContent = 'Enroll Now';
            btn.classList.remove('enrolled');
        }
    }

    function renderPrereqNotice() {
        var box = el('prereqNotice');
        if (!box) return;
        if (getFlag(ENROLL_KEY)) { box.innerHTML = ''; return; }
        if (!PREREQS.length) { box.innerHTML = ''; return; }

        var missing = PREREQS.filter(function (p) { return !prereqSatisfied(p); });
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
            var first = firstLessonUrl();
            if (first) { window.location.href = first; return; }
        }

        var missing = PREREQS.filter(function (p) { return !prereqSatisfied(p); });
        if (missing.length) {
            renderPrereqNotice();
            var msg = el('enrollMessage');
            if (msg) {
                msg.innerHTML = '<p class="flow-note warn">Enrollment blocked. ' +
                    'Finish the missing prerequisite(s) above, or pass their Bypass Exams first.</p>';
            }
            var box = el('prereqNotice');
            if (box) box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            return;
        }

        if (LESSONS.length === 0) {
            alert('This course has no curriculum yet. Check back once the instructor publishes lessons.');
            return;
        }

        setFlag(ENROLL_KEY);
        pushNotification('You enrolled in "' + (course ? course.title : courseKey) + '". The first lesson is unlocked.');
        refreshEnrollState();
        renderPrereqNotice();
        applyLessonLocks();
        var m = el('enrollMessage');
        if (m) {
            m.innerHTML = '<p class="flow-note success">Enrolled! The first lesson is unlocked. ' +
                (TRACK ? 'You can also enroll in the full "' + TRACK + '" track below.' : '') + '</p>';
        }
    }

    function enrollTrack() {
        if (!TRACK) return;
        var trackSlug = slugify(TRACK);
        setFlag('learnova_track_enrolled_' + trackSlug);
        TRACK_COURSES.forEach(function (name) {
            setFlag('learnova_enrolled_' + slugify(name));
        });
        pushNotification('You joined the "' + TRACK + '" track.');
        alert('You are now enrolled in the "' + TRACK + '" track.');
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

        var done = LESSONS.filter(function (name) {
            return getFlag('learnova_quiz_pass_' + slugify(name));
        }).length;
        var count = el('curriculumCount');
        if (count && curriculum) {
            count.textContent = curriculum.modules.length + ' Modules · ' + LESSONS.length + ' Lessons · ' + done + ' completed';
        }
    }

    /* ---------- Completion & certificate ---------- */
    function applyCompletion() {
        if (!getFlag(ENROLL_KEY)) return;
        if (!curriculum || LESSONS.length === 0) return;

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
                    '<div class="certificate-title">' + ((course && course.title) || courseKey) + '</div>' +
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
            pushNotification('You reviewed "' + ((course && course.title) || courseKey) + '" with ' + rating + ' stars.');
            if (message) message.innerHTML = '<p class="flow-note success">Review submitted (rating ' + rating + '/5). It cannot be edited or deleted.</p>';
            stars.forEach(function (s) { s.classList.add('disabled'); });
            textarea.disabled = true;
            submitBtn.disabled = true;
        });
    }

    /* ---------- Wire-up ---------- */
    document.addEventListener('DOMContentLoaded', function () {
        setHero();
        renderCurriculum();
        refreshEnrollState();
        renderPrereqNotice();
        applyLessonLocks();
        applyCompletion();

        var enrollBtn = el('enrollBtn');
        if (enrollBtn) enrollBtn.addEventListener('click', tryEnroll);

        var trackBtn = el('trackEnrollBtn');
        if (trackBtn && TRACK) trackBtn.style.display = '';

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
