/* ==========================================================================
   Instructor Courses (courses.html)
   Course lifecycle (spec 2.2): draft -> pending -> published.
   Fully data-driven from the shared course registry (learnova_courses).
   - Instructor creates content in draft, submits it for review (pending),
     and only an Admin can publish. Instructors can delete their own courses.
   ========================================================================== */

(function () {
    'use strict';

    var COURSES_KEY = LearnovaConstants.COURSES_KEY;
    var COURSE_STATUS = LearnovaConstants.COURSE_STATUS;

    var STATUS_LABEL = {};
    STATUS_LABEL[COURSE_STATUS.DRAFT] = 'Draft';
    STATUS_LABEL[COURSE_STATUS.PENDING] = 'Pending';
    STATUS_LABEL[COURSE_STATUS.PUBLISHED] = 'Published';

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function readCourses() {
        var courses = [];
        try { courses = JSON.parse(localStorage.getItem(COURSES_KEY) || '[]'); } catch (err) { courses = []; }
        return courses;
    }

    function writeCourses(courses) {
        localStorage.setItem(COURSES_KEY, JSON.stringify(courses));
    }

    function myCourses() {
        var user = LearnovaSession.currentUser();
        var email = user && user.email;
        var courses = readCourses();
        if (!email) return courses;
        return courses.filter(function (c) { return c.instructorEmail === email; });
    }

    function moduleCount(slug) {
        try {
            var raw = JSON.parse(localStorage.getItem('learnova_curriculum_' + slug) || 'null');
            if (raw && Array.isArray(raw.modules)) return raw.modules.length;
        } catch (err) { /* ignore */ }
        return 0;
    }

    function showToast(message) {
        var note = document.createElement('div');
        note.className = 'course-toast';
        note.textContent = message;
        document.body.appendChild(note);
        setTimeout(function () {
            if (note.parentNode) note.parentNode.removeChild(note);
        }, 2600);
    }

    function renderCourses() {
        var list = document.getElementById('courseList');
        var empty = document.getElementById('coursesEmpty');
        if (!list) return;

        var courses = myCourses();

        if (empty) empty.style.display = courses.length ? 'none' : '';
        if (!courses.length) {
            list.innerHTML = '';
            return;
        }

        list.innerHTML = courses.map(function (course) {
            var status = course.status || COURSE_STATUS.DRAFT;
            var modules = moduleCount(course.slug);
            var editHref = 'course-editor.html?course=' + encodeURIComponent(course.slug);
            var actions = '';
            if (status === COURSE_STATUS.DRAFT) {
                actions += '<button class="btn btn-ghost btn-sm" data-action="submit-review" data-slug="' + esc(course.slug) + '">Submit for Review</button>';
            }
            if (status === COURSE_STATUS.PENDING) {
                actions += '<span class="status-note">Awaiting Admin publish</span>';
            }
            actions += '<button class="btn btn-danger btn-sm" data-action="delete-course" data-slug="' + esc(course.slug) + '">Delete</button>';

            return '<div class="course-list-item" data-status="' + status + '">' +
                '<div class="course-list-main">' +
                    '<span class="course-list-title">' + esc(course.title) + '</span>' +
                    '<div class="course-list-meta">' +
                        '<span class="track-badge">' + esc(course.track || 'Standalone') + '</span>' +
                        '<span class="meta-item">' + modules + ' Modules</span>' +
                        '<span class="status-badge ' + status + '">' + (STATUS_LABEL[status] || 'Draft') + '</span>' +
                    '</div>' +
                '</div>' +
                '<div class="course-list-actions">' +
                    '<a class="btn btn-outline btn-sm" href="' + editHref + '">Edit Course</a>' +
                    '<a class="btn btn-ghost btn-sm" href="' + editHref + '">View Modules</a>' +
                    actions +
                '</div>' +
            '</div>';
        }).join('');
    }

    function createCourse(title, track) {
        var slug = slugify(title);
        var courses = readCourses().filter(function (c) { return c.slug !== slug; });
        var user = LearnovaSession.currentUser();
        courses.unshift({
            slug: slug,
            title: title,
            description: '',
            track: track,
            status: COURSE_STATUS.DRAFT,
            instructorEmail: user ? (user.email || '') : ''
        });
        writeCourses(courses);
        if (!localStorage.getItem('learnova_curriculum_' + slug)) {
            localStorage.setItem('learnova_curriculum_' + slug, JSON.stringify({ modules: [] }));
        }
        showToast('Course created. Now build its modules and lessons.');
        window.location.href = 'course-editor.html?course=' + encodeURIComponent(slug);
    }

    function submitForReview(slug) {
        var courses = readCourses();
        var course = courses.filter(function (c) { return c.slug === slug; })[0];
        if (!course) return;
        course.status = COURSE_STATUS.PENDING;
        writeCourses(courses);
        renderCourses();
        showToast('Course submitted for review. An Admin will publish it.');
    }

    function deleteCourse(slug) {
        var courses = readCourses();
        var course = courses.filter(function (c) { return c.slug === slug; })[0];
        if (!course) return;
        if (!confirm('Delete course "' + course.title + '"? This cannot be undone.')) return;
        writeCourses(courses.filter(function (c) { return c.slug !== slug; }));
        localStorage.removeItem('learnova_curriculum_' + slug);
        renderCourses();
        showToast('Course deleted.');
    }

    document.addEventListener('DOMContentLoaded', function () {
        renderCourses();

        var toggleBtn = document.getElementById('toggleCreateBtn');
        var emptyCreateBtn = document.getElementById('emptyCreateBtn');
        var createCard = document.getElementById('createCourseCard');
        var cancelBtn = document.getElementById('cancelCreateBtn');

        function toggleCard() {
            if (createCard) {
                createCard.style.display = createCard.style.display === 'none' ? 'block' : 'none';
            }
        }

        if (toggleBtn) toggleBtn.addEventListener('click', toggleCard);
        if (emptyCreateBtn) emptyCreateBtn.addEventListener('click', toggleCard);
        if (cancelBtn && createCard) {
            cancelBtn.addEventListener('click', function () {
                createCard.style.display = 'none';
            });
        }

        var createBtn = document.getElementById('createCourseBtn');
        if (createBtn) {
            createBtn.addEventListener('click', function () {
                var titleInput = document.getElementById('newCourseTitle');
                var trackSelect = document.getElementById('newCourseTrack');
                var title = titleInput.value.trim();
                if (!title) {
                    alert('Please enter a course title.');
                    return;
                }
                createCourse(title, trackSelect.value);
            });
        }

        document.addEventListener('click', function (event) {
            var btn = event.target.closest('[data-action]');
            if (!btn) return;

            var action = btn.getAttribute('data-action');
            var slug = btn.getAttribute('data-slug');
            if (action === 'submit-review') {
                event.preventDefault();
                submitForReview(slug);
            } else if (action === 'delete-course') {
                event.preventDefault();
                deleteCourse(slug);
            }
        });
    });
})();
