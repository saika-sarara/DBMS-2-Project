/* ==========================================================================
   Course Detail page (course-detail.html)
   Data-driven: course info and curriculum come from the API layer
   (LearnovaCourseApi), which talks to the real backend when available and
   falls back to the offline mock adapter. No hardcoded demo content.
   - Enrollment only when ALL prerequisites are satisfied (AND logic, spec 3.1);
     missing prerequisites offer a Bypass Exam (spec 3.3).
   - Sequential lesson unlocking: the first lesson is open; each next lesson
     unlocks only after the previous lesson's quiz is passed (spec 4.3).
   - Lessons open into lesson-view.html (YouTube / notes / links).
   - Course completion -> auto-issued certificate (LRV-XXXX-XXXX) and the
     review form (spec 7) unlocks. Certificates and notifications are issued
     server-side / by the mock.
   ========================================================================== */
(function () {
    'use strict';

    var params = new URLSearchParams(window.location.search);
    var courseKey = params.get('course') || 'database-design';

    var course = null;
    var curriculum = null;
    var LESSONS = [];
    var PREREQS = [];

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function el(id) { return document.getElementById(id); }

    function lessonPassed(name) {
        if (course && course.progress && Array.isArray(course.progress.lessons)) {
            for (var i = 0; i < course.progress.lessons.length; i++) {
                if (course.progress.lessons[i].name === name) return !!course.progress.lessons[i].passed;
            }
        }
        return false;
    }

    function loadCourse() {
        return Promise.all([
            LearnovaCourseApi.get(courseKey).catch(function () { return null; }),
            LearnovaCourseApi.getCurriculum(courseKey).catch(function () { return null; })
        ]).then(function (results) {
            course = results[0];
            curriculum = results[1];
            LESSONS = [];
            if (curriculum) {
                curriculum.modules.forEach(function (m) {
                    (m.lessons || []).forEach(function (l) { LESSONS.push(l.name); });
                });
            }
            PREREQS = (course && course.prereqs) || [];
        });
    }

    /* ---------- Hero ---------- */

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
                var modules = curriculum.modules.length;
                meta.style.display = '';
                meta.innerHTML =
                    '<span class="meta-item"><i class="fa-regular fa-folder-open"></i> ' + modules + ' Modules</span>' +
                    '<span class="meta-item"><i class="fa-regular fa-file-lines"></i> ' + LESSONS.length + ' Lessons</span>';
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
                    '<span class="lesson-status"></span>' +
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
        if (course && course.enrolled) {
            btn.textContent = 'Continue Learning';
            btn.classList.add('enrolled');
            var msg = el('enrollMessage');
            if (msg) msg.innerHTML = '<p class="flow-note success">You are enrolled. The first lesson is unlocked — complete each quiz (≥60%) to unlock the next.</p>';
            var trackBtn = el('trackEnrollBtn');
            if (trackBtn && course && course.track) trackBtn.style.display = '';
        } else {
            btn.textContent = 'Enroll Now';
            btn.classList.remove('enrolled');
        }
    }

    function renderPrereqNotice() {
        var box = el('prereqNotice');
        if (!box) return;
        if (course && course.enrolled) { box.innerHTML = ''; return; }
        if (!PREREQS.length) { box.innerHTML = ''; return; }

        var missing = PREREQS.filter(function (p) { return !p.satisfied; });
        if (!missing.length) { box.innerHTML = ''; return; }

        var list = missing.map(function (p) {
            return '<li>' +
                '<span>' + p.title + '</span>' +
                '<a class="btn btn-outline btn-sm" href="quiz-attempt.html?bypass=1&course=' +
                    encodeURIComponent(courseKey) + '&lesson=' +
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
        if (course && course.enrolled) {
            var first = firstLessonUrl();
            if (first) { window.location.href = first; return; }
        }

        var missing = PREREQS.filter(function (p) { return !p.satisfied; });
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
            LearnovaToast.info('This course has no curriculum yet. Check back once the instructor publishes lessons.');
            return;
        }

        LearnovaEnrollmentApi.enroll(courseKey).then(function () {
            course.enrolled = true;
            refreshEnrollState();
            renderPrereqNotice();
            applyLessonLocks();
            var m = el('enrollMessage');
            if (m) {
                m.innerHTML = '<p class="flow-note success">Enrolled! The first lesson is unlocked. ' +
                    (course && course.track ? 'You can also enroll in the full "' + course.track + '" track below.' : '') + '</p>';
            }
        }).catch(function (err) {
            LearnovaToast.error((err && err.message) || 'Could not enroll. Please check the prerequisites.');
            refreshEnrollState();
            renderPrereqNotice();
        });
    }

    function enrollTrack() {
        if (!course || !course.track) return;
        var trackCourses = (course.trackCourses || []).map(function (name) { return slugify(name); });
        Promise.all(trackCourses.map(function (slug) {
            return LearnovaEnrollmentApi.enroll(slug).catch(function () { return null; });
        })).then(function () {
            LearnovaToast.success('You are now enrolled in the "' + course.track + '" track.');
            var trackBtn = el('trackEnrollBtn');
            if (trackBtn) trackBtn.style.display = 'none';
        });
    }

    /* ---------- Sequential lesson unlocking (spec 4.3) ---------- */

    function applyLessonLocks() {
        var rows = document.querySelectorAll('.lesson-row');
        var enrolled = !!(course && course.enrolled);
        var prevPassed = false;

        rows.forEach(function (row, i) {
            var lessonName = row.getAttribute('data-lesson') || '';
            var isPassed = lessonPassed(lessonName);
            var unlocked = false;

            if (i === 0) {
                unlocked = true;
            } else if (enrolled && prevPassed) {
                unlocked = true;
            } else if (isPassed) {
                unlocked = true;
            }

            var status = row.querySelector('.lesson-status');
            if (isPassed) {
                row.classList.remove('locked');
                row.querySelector('.lesson-icon').innerHTML = '<i class="fa-solid fa-circle-check"></i>';
                row.removeAttribute('title');
                if (status) { status.className = 'lesson-status completed'; status.innerHTML = '<i class="fa-solid fa-check"></i> Completed'; }
            } else if (unlocked) {
                row.classList.remove('locked');
                row.querySelector('.lesson-icon').innerHTML = '<i class="fa-solid fa-circle-play"></i>';
                row.removeAttribute('title');
                if (status) { status.className = 'lesson-status available'; status.innerHTML = '<i class="fa-solid fa-play"></i> Available'; }
            } else {
                row.classList.add('locked');
                row.querySelector('.lesson-icon').innerHTML = '<i class="fa-solid fa-lock"></i>';
                row.setAttribute('title', 'Complete the previous lesson\'s quiz (≥60%) to unlock.');
                if (status) {
                    status.className = 'lesson-status locked';
                    status.innerHTML = '<i class="fa-solid fa-lock"></i> Locked';
                }
                var pill = row.querySelector('.lesson-quiz-pill');
                if (pill && pill.getAttribute('data-bypass') === null) {
                    pill.setAttribute('data-bypass', '1');
                    pill.innerHTML = '<a class="bypass-exam-link" href="quiz-attempt.html?bypass=1&course=' +
                        encodeURIComponent(courseKey) + '&lesson=' +
                        encodeURIComponent(lessonName) + '">Take Bypass Exam</a>';
                }
            }

            prevPassed = isPassed;
        });

        var done = LESSONS.filter(lessonPassed).length;
        var count = el('curriculumCount');
        if (count && curriculum) {
            count.textContent = curriculum.modules.length + ' Modules · ' + LESSONS.length + ' Lessons · ' + done + ' completed';
        }
    }

    /* ---------- Completion & certificate ---------- */

    function applyCompletion() {
        var banner = el('completionBanner');
        if (!banner) return;

        if (!(course && course.completed)) { banner.innerHTML = ''; return; }

        banner.innerHTML =
            '<div class="certificate-banner">' +
                '<div class="certificate-kicker">Course Certificate</div>' +
                '<div class="certificate-title">' + ((course && course.title) || courseKey) + '</div>' +
                '<div class="certificate-code">' + (course.certCode || '') + '</div>' +
                '<p>Issued automatically on completion. Verify any code via the public certificate lookup.</p>' +
            '</div>';
    }

    /* ---------- Reviews (spec 7) ---------- */

    function setupReview(completed, existingReview) {
        var stars = document.querySelectorAll('.review-star');
        var textarea = el('reviewText');
        var submitBtn = el('submitReviewBtn');
        var note = el('reviewNote');
        var message = el('reviewMessage');
        var rating = 0;

        if (existingReview) {
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
                LearnovaToast.error('Please select a star rating (1-5) before submitting.');
                return;
            }
            var comment = textarea.value.trim();
            LearnovaReviewApi.create(courseKey, { rating: rating, comment: comment }).then(function () {
                if (message) message.innerHTML = '<p class="flow-note success">Review submitted (rating ' + rating + '/5). It cannot be edited or deleted.</p>';
                stars.forEach(function (s) { s.classList.add('disabled'); });
                textarea.disabled = true;
                submitBtn.disabled = true;
            }).catch(function (err) {
                LearnovaToast.error((err && err.message) || 'Could not submit your review.');
            });
        });
    }

    /* ---------- Wire-up ---------- */

    document.addEventListener('DOMContentLoaded', function () {
        loadCourse().then(function () {
            return LearnovaReviewApi.listByCourse(courseKey).catch(function () { return []; });
        }).then(function (reviews) {
            var user = LearnovaSession.currentUser();
            var existing = null;
            for (var i = 0; i < reviews.length; i++) {
                if (reviews[i].email === (user && user.email)) { existing = reviews[i]; break; }
            }

            setHero();
            renderCurriculum();
            refreshEnrollState();
            renderPrereqNotice();
            applyLessonLocks();
            applyCompletion();
            setupReview(course && course.completed, existing);

            var enrollBtn = el('enrollBtn');
            if (enrollBtn) enrollBtn.addEventListener('click', tryEnroll);

            var trackBtn = el('trackEnrollBtn');
            if (trackBtn && course && course.track) trackBtn.style.display = '';

            document.addEventListener('click', function (event) {
                if (event.target.closest('.bypass-exam-link')) return;
                var row = event.target.closest('.lesson-row.locked');
                if (row) {
                    event.preventDefault();
                    LearnovaToast.info('This lesson is locked. Complete the previous lesson\'s quiz (≥60%) to unlock it, or take the bypass exam.');
                }
            });
        });
    });
})();
