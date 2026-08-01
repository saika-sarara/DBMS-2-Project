/* ==========================================================================
   Instructor Courses (courses.html)
   Course lifecycle (spec 2.2): draft -> pending -> published.
   Instructor creates content in draft, submits it for review (pending),
   and only an Admin can publish. Instructors can delete their own courses.
   ========================================================================== */

var COURSE_STATUS = window.LearnovaConstants ? LearnovaConstants.COURSE_STATUS : {
    DRAFT: 'draft',
    PENDING: 'pending',
    PUBLISHED: 'published'
};

var STATUS_LABEL = {};
STATUS_LABEL[COURSE_STATUS.DRAFT] = 'Draft';
STATUS_LABEL[COURSE_STATUS.PENDING] = 'Pending';
STATUS_LABEL[COURSE_STATUS.PUBLISHED] = 'Published';

function updateStatusBadge(item) {
    var status = item.getAttribute('data-status');
    var badge = item.querySelector('.status-badge');
    if (!badge) return;
    badge.textContent = STATUS_LABEL[status] || 'Draft';
    badge.className = 'status-badge ' + status;
}

function deleteCourse(btn) {
    if (confirm('Delete this course? This cannot be undone.')) {
        btn.closest('.course-list-item').remove();
    }
}

function submitCourseForReview(item) {
    item.setAttribute('data-status', COURSE_STATUS.PENDING);
    updateStatusBadge(item);

    var submitBtn = item.querySelector('[data-action="submit-review"]');
    if (submitBtn) {
        submitBtn.outerHTML = '<span class="status-note">Awaiting Admin publish</span>';
    }

    var note = document.createElement('div');
    note.className = 'course-toast';
    note.textContent = 'Course submitted for review. An Admin will publish it.';
    document.body.appendChild(note);
    setTimeout(function () {
        if (note.parentNode) note.parentNode.removeChild(note);
    }, 2600);
}

document.addEventListener('DOMContentLoaded', function () {
    var toggleBtn = document.getElementById('toggleCreateBtn');
    var createCard = document.getElementById('createCourseCard');
    var cancelBtn = document.getElementById('cancelCreateBtn');

    if (toggleBtn && createCard) {
        toggleBtn.addEventListener('click', function () {
            createCard.style.display = createCard.style.display === 'none' ? 'block' : 'none';
        });
    }
    if (cancelBtn && createCard) {
        cancelBtn.addEventListener('click', function () {
            createCard.style.display = 'none';
        });
    }

    document.querySelectorAll('.course-list-item').forEach(function (item) {
        updateStatusBadge(item);
    });

    document.addEventListener('click', function (event) {
        var submitBtn = event.target.closest('[data-action="submit-review"]');
        if (submitBtn) {
            event.preventDefault();
            var item = submitBtn.closest('.course-list-item');
            if (item.getAttribute('data-status') === COURSE_STATUS.DRAFT) {
                submitCourseForReview(item);
            }
        }
    });

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

            var list = document.getElementById('courseList');
            var item = document.createElement('div');
            item.className = 'course-list-item';
            item.setAttribute('data-status', COURSE_STATUS.DRAFT);
            item.innerHTML =
                '<div class="course-list-main">' +
                    '<span class="course-list-title"></span>' +
                    '<div class="course-list-meta">' +
                        '<span class="track-badge"></span>' +
                        '<span class="meta-item">0 Modules</span>' +
                        '<span class="status-badge ' + COURSE_STATUS.DRAFT + '">Draft</span>' +
                    '</div>' +
                '</div>' +
                '<div class="course-list-actions">' +
                    '<a class="btn btn-outline btn-sm" href="course-editor.html">Edit Course</a>' +
                    '<a class="btn btn-ghost btn-sm" href="course-editor.html">View Modules</a>' +
                    '<button class="btn btn-ghost btn-sm" data-action="submit-review">Submit for Review</button>' +
                    '<button class="btn btn-danger btn-sm" onclick="deleteCourse(this)">Delete</button>' +
                '</div>';

            item.querySelector('.course-list-title').textContent = title;
            item.querySelector('.track-badge').textContent = trackSelect.value;

            list.insertBefore(item, list.firstChild);
            titleInput.value = '';
            createCard.style.display = 'none';
        });
    }
});
