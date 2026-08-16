/* ==========================================================================
   Course Detail page (course-detail.html)
   Data-driven against the real backend:
   - course info from GET /courses/{courseId} (fn_course_detail)
   - curriculum from GET /courses/{courseId}/syllabus (fn_course_syllabus)
   - per-lesson access (preview / available / locked) comes from the
     database; this page renders it verbatim and never recomputes access.
   - Enrollment is display-only: eligibility (including prerequisites) is
     decided by the backend/database via POST /enrollments/courses/{id}.
     This page calls the API and surfaces the returned response; it does not
     gate enrollment locally.
   - Reviews stay one-per-student, after completion, non-editable (spec 7).
   ========================================================================== */
(function () {
    'use strict';

    var params = new URLSearchParams(window.location.search);
    var rawCourse = params.get('course') || '';
    var courseId = 0;

    var course = null;
    var syllabus = null;
    var LESSONS = [];

    function el(id) { return document.getElementById(id); }

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    /* The backend resolves courses by numeric id. Links may still carry a
       slug (legacy cards), so map a slug to its id through the catalogue
       before loading. */
    function resolveCourseId(raw) {
        var trimmed = String(raw || '').trim();
        if (/^\d+$/.test(trimmed)) return Promise.resolve(Number(trimmed));
        return LearnovaCourseApi.list().then(function (cards) {
            for (var i = 0; i < (cards || []).length; i++) {
                if (String(cards[i].slug) === trimmed) {
                    var id = cards[i].id !== undefined && cards[i].id !== null ? cards[i].id : null;
                    return Number(id);
                }
            }
            return 0;
        }).catch(function () { return 0; });
    }

    function loadCourse() {
        return resolveCourseId(rawCourse).then(function (id) {
            courseId = id;
            if (!Number.isInteger(courseId) || courseId < 1) {
                throw new Error('Invalid course id.');
            }

            return Promise.all([
                LearnovaCourseApi.get(courseId),
                LearnovaCourseApi.getSyllabus(courseId)
            ]).then(function (results) {
                course = results[0];
                syllabus = results[1];
                LESSONS = [];
                if (syllabus) {
                    syllabus.modules.forEach(function (module) {
                        (module.lessons || []).forEach(function (lesson) {
                            LESSONS.push(lesson);
                        });
                    });
                }
            });
        });
    }

    /* ---------- Hero ---------- */

    function setHero() {
        var title = course ? course.title : 'Course';
        var t = el('courseTitle');
        if (t) t.textContent = title;

        var sub = el('courseSubtitle');
        if (sub) {
            sub.textContent = (course && (course.shortDescription || course.description))
                ? (course.shortDescription || course.description)
                : 'This course hasn\'t been published yet. Check back soon for content.';
        }

        var tag = el('courseCategoryTag');
        if (tag) tag.textContent = (course && course.categoryName) ? course.categoryName : 'Course';

        var meta = el('courseMeta');
        if (meta) {
            if (course) {
                meta.style.display = '';
                var rating = course.avgRating !== undefined && course.avgRating !== null
                    ? Number(course.avgRating).toFixed(1)
                    : null;
                var parts = [
                    '<span class="meta-item"><i class="fa-regular fa-folder-open"></i> ' + (course.totalModules || 0) + ' Modules</span>',
                    '<span class="meta-item"><i class="fa-regular fa-file-lines"></i> ' + (course.totalLessons || 0) + ' Lessons</span>',
                    '<span class="meta-item"><i class="fa-solid fa-signal"></i> ' + esc(course.difficulty || '') + '</span>'
                ];
                if (course.instructorName) {
                    parts.push('<span class="meta-item"><i class="fa-solid fa-chalkboard-user"></i> ' + esc(course.instructorName) + '</span>');
                }
                if (rating !== null) {
                    parts.push('<span class="meta-item"><i class="fa-solid fa-star"></i> ' + rating + ' (' + (course.reviewCount || 0) + ')</span>');
                }
                meta.innerHTML = parts.join('');
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

        if (!syllabus || LESSONS.length === 0) {
            box.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-box-open"></i></div>' +
                    '<h3>No curriculum yet</h3>' +
                    '<p>The instructor hasn\'t published lessons for this course. Course content will appear here once it is ready.</p>' +
                '</div>';
            if (count) count.textContent = '0 Lessons';
            return;
        }

        if (count) count.textContent = syllabus.modules.length + ' Modules · ' + LESSONS.length + ' Lessons';

        box.innerHTML = syllabus.modules.map(function (module) {
            var lessonsHtml = (module.lessons || []).map(function (lesson) {
                var status = lesson.accessStatus || 'locked';
                var isLocked = status === 'locked';
                var href = 'lesson-view.html?course=' + encodeURIComponent(courseId) +
                    '&lesson=' + encodeURIComponent(lesson.title);

                return '<a class="lesson-row' + (isLocked ? ' locked' : '') + '" href="' +
                        (isLocked ? '#' : esc(href)) + '" data-lesson-id="' + lesson.lessonId + '" ' +
                        (isLocked ? 'title="This lesson is locked. Enroll in the course to unlock it."' : '') + '>' +
                    '<span class="lesson-icon"><i class="fa-solid ' +
                        (status === 'preview' ? 'fa-circle-play' : (isLocked ? 'fa-lock' : 'fa-circle-play')) + '"></i></span>' +
                    '<span class="lesson-row-name">' + esc(lesson.title) + '</span>' +
                    '<span class="lesson-status ' + status + '">' +
                        esc(status === 'preview' ? 'Preview' : (isLocked ? 'Locked' : 'Available')) +
                    '</span>' +
                    '<span class="lesson-quiz-pill">Lesson</span>' +
                '</a>';
            }).join('');

            return '<details class="module-item" open>' +
                '<summary>' +
                    '<span class="module-title-lg">' + esc(module.title) + '</span>' +
                    '<span class="module-count">' + (module.lessons || []).length + ' Lessons</span>' +
                '</summary>' +
                '<div class="module-lesson-list">' + lessonsHtml + '</div>' +
            '</details>';
        }).join('');
    }

    /* ---------- Enrollment (display-only; DB decides) ---------- */

    function refreshEnrollState() {
        var btn = el('enrollBtn');
        if (!btn) return;

        if (course && course.enrolled) {
            btn.textContent = 'Continue Learning';
            btn.classList.add('enrolled');
            var msg = el('enrollMessage');
            if (msg) msg.innerHTML = '<p class="flow-note success">You are enrolled. Open a lesson to begin — pass each quiz (≥60%) to progress.</p>';
        } else if (course && course.locked) {
            btn.textContent = 'Enroll Now';
            btn.classList.remove('enrolled');
            var lockedMsg = el('enrollMessage');
            if (lockedMsg) {
                lockedMsg.innerHTML = '<p class="flow-note error">' + esc(course.lockReason || 'This course is currently locked.') + '</p>';
            }
        } else {
            btn.textContent = 'Enroll Now';
            btn.classList.remove('enrolled');
            var clearMsg = el('enrollMessage');
            if (clearMsg) clearMsg.innerHTML = '';
        }
    }

    function tryEnroll() {
        if (course && course.enrolled) {
            if (LESSONS.length > 0) {
                window.location.href = 'lesson-view.html?course=' + encodeURIComponent(courseId) +
                    '&lesson=' + encodeURIComponent(LESSONS[0].title);
            }
            return;
        }

        if (course && course.locked) {
            LearnovaToast.info(course.lockReason || 'This course is locked.');
            return;
        }

        if (LESSONS.length === 0) {
            LearnovaToast.info('This course has no curriculum yet. Check back once the instructor publishes lessons.');
            return;
        }

        LearnovaEnrollmentApi.enroll(courseId).then(function () {
            return loadCourse();
        }).then(function () {
            setHero();
            renderCurriculum();
            refreshEnrollState();
            applyLessonLocks();
            var m = el('enrollMessage');
            if (m) m.innerHTML = '<p class="flow-note success">Enrolled! The database has granted you access to this course.</p>';
        }).catch(function (err) {
            LearnovaToast.error((err && err.message) || 'Could not enroll. Please check the prerequisites.');
            refreshEnrollState();
        });
    }

    /* ---------- Lesson access (backend-provided) ---------- */

    function applyLessonLocks() {
        var rows = document.querySelectorAll('.lesson-row');
        rows.forEach(function (row) {
            var status = row.className.indexOf('locked') !== -1 ? 'locked' : 'available';
            var statusEl = row.querySelector('.lesson-status');
            if (statusEl) {
                statusEl.className = 'lesson-status ' + status;
            }
        });

        var count = el('curriculumCount');
        if (count && syllabus) {
            count.textContent = syllabus.modules.length + ' Modules · ' + LESSONS.length + ' Lessons';
        }
    }

    /* ---------- Completion banner ---------- */

    function applyCompletion() {
        var banner = el('completionBanner');
        if (!banner) return;

        if (!(course && course.completed)) { banner.innerHTML = ''; return; }

        banner.innerHTML =
            '<div class="certificate-banner">' +
                '<div class="certificate-kicker">Course Certificate</div>' +
                '<div class="certificate-title">' + esc(course.title || '') + '</div>' +
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
            LearnovaReviewApi.create(courseId, { rating: rating, comment: comment }).then(function () {
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
        var failBox = el('curriculumContainer');

        loadCourse().then(function () {
            return LearnovaReviewApi.listByCourse(courseId).catch(function () { return []; });
        }).then(function (reviews) {
            var user = LearnovaSession.currentUser();
            var existing = null;
            for (var i = 0; i < reviews.length; i++) {
                if (reviews[i].email === (user && user.email)) { existing = reviews[i]; break; }
            }

            setHero();
            renderCurriculum();
            refreshEnrollState();
            applyLessonLocks();
            applyCompletion();
            setupReview(course && course.completed, existing);

            var enrollBtn = el('enrollBtn');
            if (enrollBtn) enrollBtn.addEventListener('click', tryEnroll);

            document.addEventListener('click', function (event) {
                var row = event.target.closest('.lesson-row.locked');
                if (row) {
                    event.preventDefault();
                    LearnovaToast.info('This lesson is locked. Enroll in the course to unlock it.');
                }
            });
        }).catch(function (err) {
            if (failBox) {
                failBox.innerHTML =
                    '<div class="empty-state">' +
                        '<div class="empty-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>' +
                        '<h3>Could not load this course</h3>' +
                        '<p>' + esc((err && err.message) || 'Invalid course id.') + '</p>' +
                        '<a class="btn btn-outline btn-sm" href="catalog.html">Back to Catalog</a>' +
                    '</div>';
            }
        });
    });
})();
