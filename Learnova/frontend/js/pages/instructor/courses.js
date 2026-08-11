/* ==========================================================================
   Instructor Courses (courses.html)
   Course lifecycle (spec 2.2): draft -> pending_review -> published /
   rejected / archived. Fully data-driven through LearnovaInstructorApi:
   - the course list, create and submit/delete actions all hit the backend,
     which delegates every rule to PostgreSQL (ownership, editable state).
   - Only draft or rejected courses can be deleted (database LTC12 rule).
   - Admins publish/reject from the admin dashboard.
   ========================================================================== */

(function () {
    'use strict';

    var COURSE_STATUS = LearnovaConstants.COURSE_STATUS;

    var STATUS_LABEL = {};
    STATUS_LABEL[COURSE_STATUS.DRAFT] = 'Draft';
    STATUS_LABEL[COURSE_STATUS.PENDING_REVIEW] = 'Pending Review';
    STATUS_LABEL[COURSE_STATUS.PUBLISHED] = 'Published';
    STATUS_LABEL[COURSE_STATUS.REJECTED] = 'Rejected';
    STATUS_LABEL[COURSE_STATUS.ARCHIVED] = 'Archived';

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
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

    function isDeletable(status) {
        return status === COURSE_STATUS.DRAFT ||
            status === COURSE_STATUS.REJECTED;
    }

    function renderCourses() {
        var list = document.getElementById('courseList');
        var empty = document.getElementById('coursesEmpty');
        if (!list) return;

        LearnovaInstructorApi.listCourses().then(function (courses) {
            courses = courses || [];

            if (empty) empty.style.display = courses.length ? 'none' : '';
            if (!courses.length) {
                list.innerHTML = '';
                return;
            }

            list.innerHTML = courses.map(function (course) {
                var status = course.status || COURSE_STATUS.DRAFT;
                var editHref = 'course-editor.html?course=' + encodeURIComponent(course.courseId);
                var actions = '';

                if (status === COURSE_STATUS.DRAFT || status === COURSE_STATUS.REJECTED) {
                    actions += '<button class="btn btn-ghost btn-sm" data-action="submit-review" data-course-id="' +
                        course.courseId + '">Submit for Review</button>';
                }
                if (status === COURSE_STATUS.PENDING_REVIEW) {
                    actions += '<span class="status-note">Awaiting Admin publish</span>';
                }
                if (isDeletable(status)) {
                    actions += '<button class="btn btn-danger btn-sm" data-action="delete-course" data-course-id="' +
                        course.courseId + '">Delete</button>';
                }

                var rejectionNote = status === COURSE_STATUS.REJECTED && course.rejectionReason
                    ? '<span class="status-note rejection">Rejected: ' + esc(course.rejectionReason) + '</span>'
                    : '';

                return '<div class="course-list-item" data-status="' + esc(status) + '">' +
                    '<div class="course-list-main">' +
                        '<span class="course-list-title">' + esc(course.title) + '</span>' +
                        '<div class="course-list-meta">' +
                            '<span class="track-badge">' + esc(course.categoryName || 'Uncategorized') + '</span>' +
                            '<span class="meta-item">' + (course.moduleCount || 0) + ' Modules</span>' +
                            '<span class="meta-item">' + (course.lessonCount || 0) + ' Lessons</span>' +
                            '<span class="status-badge ' + esc(status) + '">' + (STATUS_LABEL[status] || 'Draft') + '</span>' +
                        '</div>' +
                        rejectionNote +
                    '</div>' +
                    '<div class="course-list-actions">' +
                        '<a class="btn btn-outline btn-sm" href="' + editHref + '">Edit Course</a>' +
                        actions +
                    '</div>' +
                '</div>';
            }).join('');
        }).catch(function (err) {
            list.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>' +
                    '<h3>Could not load your courses</h3>' +
                    '<p>' + esc((err && err.message) || 'Please try again.') + '</p>' +
                '</div>';
        });
    }

    function loadCategories() {
        return LearnovaCourseApi.getCatalogueCategories()
            .then(function (categories) {
                var select = document.getElementById('newCourseCategory');
                if (!select) return;
                var options = '<option value="">No category</option>';
                options += (categories || []).map(function (category) {
                    return '<option value="' + esc(category.id) + '">' +
                        esc(category.name) + '</option>';
                }).join('');
                select.innerHTML = options;
            })
            .catch(function () { /* categories are optional for creation */ });
    }

    function createCourse(title, categoryId, difficulty) {
        var payload = { title: title };
        if (categoryId) payload.categoryId = Number(categoryId);
        if (difficulty) payload.difficulty = difficulty;

        LearnovaInstructorApi.createCourse(payload).then(function (course) {
            showToast('Course created. Now build its modules and lessons.');
            window.location.href = 'course-editor.html?course=' +
                encodeURIComponent(course.courseId);
        }).catch(function (err) {
            showToast((err && err.message) || 'Could not create course.');
        });
    }

    function submitForReview(courseId) {
        LearnovaInstructorApi.submitCourse(courseId).then(function () {
            renderCourses();
            showToast('Course submitted for review. An Admin will publish it.');
        }).catch(function (err) {
            showToast((err && err.message) || 'Could not submit course.');
        });
    }

    function deleteCourse(courseId) {
        LearnovaInstructorApi.listCourses().then(function (courses) {
            var course = (courses || []).filter(function (c) {
                return String(c.courseId) === String(courseId);
            })[0];
            var title = course ? course.title : 'this course';
            return LearnovaConfirm.ask('Delete "' + title + '"? This cannot be undone.').then(function (ok) {
                if (!ok) return;
                return LearnovaInstructorApi.deleteCourse(courseId).then(function () {
                    renderCourses();
                    showToast('Course deleted.');
                });
            });
        }).catch(function (err) {
            showToast((err && err.message) || 'Could not delete course.');
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        renderCourses();
        loadCategories();

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
                var categorySelect = document.getElementById('newCourseCategory');
                var difficultySelect = document.getElementById('newCourseDifficulty');
                var title = titleInput.value.trim();
                if (!title) {
                    LearnovaToast.error('Please enter a course title.');
                    return;
                }
                createCourse(
                    title,
                    categorySelect.value,
                    difficultySelect.value
                );
            });
        }

        document.addEventListener('click', function (event) {
            var btn = event.target.closest('[data-action]');
            if (!btn) return;

            var action = btn.getAttribute('data-action');
            var courseId = btn.getAttribute('data-course-id');
            if (action === 'submit-review') {
                event.preventDefault();
                submitForReview(courseId);
            } else if (action === 'delete-course') {
                event.preventDefault();
                deleteCourse(courseId);
            }
        });
    });
})();
