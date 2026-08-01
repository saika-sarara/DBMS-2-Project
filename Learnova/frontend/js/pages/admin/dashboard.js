/* ==========================================================================
   Admin Dashboard (dashboard.html)
   Fully data-driven; no seeded demo data.
   - Live stats from the shared registry, course store, and enroll flags.
   - Recent users from the shared registry (learnova_users), created by the
     auth mock (register / admin create-account). No seeding here.
   - Instructor requests to approve or reject (spec 1.3).
   - Course moderation to publish pending courses or delete any (spec 2.2).
   ========================================================================== */

(function () {
    'use strict';

    var REGISTRY_KEY = LearnovaConstants.USERS_KEY;
    var REQUESTS_KEY = LearnovaConstants.INSTRUCTOR_REQUEST_KEY;
    var COURSES_KEY = LearnovaConstants.COURSES_KEY;
    var NOTIFICATIONS_KEY = LearnovaConstants.NOTIFICATIONS_KEY;

    var COURSE_STATUS = LearnovaConstants.COURSE_STATUS;

    function readLS(key, fallback) {
        var raw = localStorage.getItem(key);
        if (raw) {
            try {
                var value = JSON.parse(raw);
                return Array.isArray(value) ? value : fallback;
            } catch (err) { /* fall through */ }
        }
        return fallback.slice ? fallback.slice() : fallback;
    }

    function writeLS(key, value) {
        localStorage.setItem(key, JSON.stringify(value));
    }

    function initialsOf(name) {
        var parts = (name || '').trim().split(/\s+/);
        return ((parts[0] || '')[0] || '') + ((parts[1] || '')[0] || '');
    }

    function rolesLabel(roles) {
        if (Array.isArray(roles) && roles.length) return roles.join(' + ');
        return 'Student';
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function formatDate(value) {
        if (!value) return '';
        var when = new Date(value);
        if (isNaN(when.getTime())) return esc(value);
        return when.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    }

    function pushNotification(email, message) {
        var notifications = readLS(NOTIFICATIONS_KEY, []);
        notifications.unshift({
            email: email,
            message: message,
            time: new Date().toISOString(),
            read: false
        });
        writeLS(NOTIFICATIONS_KEY, notifications);
    }

    function renderStats() {
        var users = readLS(REGISTRY_KEY, []);
        var courses = readLS(COURSES_KEY, []);
        var instructors = users.filter(function (u) {
            return (u.roles || []).indexOf(LearnovaConstants.ROLES.INSTRUCTOR) !== -1;
        }).length;
        var activeCourses = courses.filter(function (c) {
            return c.status === COURSE_STATUS.PUBLISHED;
        }).length;

        var enrollments = 0;
        for (var i = 0; i < localStorage.length; i++) {
            if (localStorage.key(i).indexOf('learnova_enrolled_') === 0) enrollments++;
        }

        setText('statTotalUsers', String(users.length));
        setText('statInstructors', String(instructors));
        setText('statActiveCourses', String(activeCourses));
        setText('statEnrollments', String(enrollments));
    }

    function setText(id, value) {
        var node = document.getElementById(id);
        if (node) node.textContent = value;
    }

    function renderRecentUsers() {
        var tbody = document.querySelector('#recentUsersTable tbody');
        if (!tbody) return;

        var users = readLS(REGISTRY_KEY, []);

        if (!users.length) {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:2rem;color:#5f5f7a;">' +
                'No users yet. Users are created via the login/register flow.</td></tr>';
            return;
        }

        tbody.innerHTML = users.slice(0, 8).map(function (user) {
            var statusClass = user.status || 'active';
            var statusLabel = { active: 'Active', suspended: 'Suspended', banned: 'Banned' }[statusClass] || 'Active';
            return '<tr>' +
                '<td>' +
                    '<div class="user-cell">' +
                        '<div class="user-avatar">' + initialsOf(user.name) + '</div>' +
                        '<div>' +
                            '<div class="user-name">' + esc(user.name) + '</div>' +
                            '<div class="user-email">' + esc(user.email) + '</div>' +
                        '</div>' +
                    '</div>' +
                '</td>' +
                '<td><span class="track-badge">' + esc(rolesLabel(user.roles)) + '</span></td>' +
                '<td><span class="status-badge ' + statusClass + '">' + statusLabel + '</span></td>' +
                '<td>' + formatDate(user.joined) + '</td>' +
            '</tr>';
        }).join('');
    }

    function renderInstructorRequests() {
        var card = document.getElementById('instructorRequestsCard');
        if (!card) return;

        var requests = readLS(REQUESTS_KEY, []);
        var pending = requests.filter(function (r) { return r.status === 'pending'; });
        var users = readLS(REGISTRY_KEY, []);

        if (!pending.length) {
            card.innerHTML = '<div class="table-message">No pending instructor requests.</div>';
            return;
        }

        var html = '<table class="data-table"><thead><tr>' +
            '<th>Name</th><th>Email</th><th>Requested</th><th>Status</th><th>Actions</th>' +
            '</tr></thead><tbody>';

        pending.forEach(function (r) {
            var alreadyInstructor = users.some(function (u) {
                return u.email === r.email && (u.roles || []).indexOf('Instructor') !== -1;
            });
            html += '<tr>' +
                '<td><div class="user-cell"><div class="user-avatar">' + initialsOf(r.name) + '</div>' +
                '<div><div class="user-name">' + esc(r.name) + '</div>' +
                '<div class="user-email">' + esc(r.note || '') + '</div></div></div></td>' +
                '<td>' + esc(r.email) + '</td>' +
                '<td>' + formatDate(r.created_at || r.requestedAt) + '</td>' +
                '<td><span class="status-badge pending">Pending</span></td>' +
                '<td><div class="table-actions">' +
                    '<button class="btn btn-primary btn-sm" data-action="approve-request" data-id="' + r.id + '">' +
                        (alreadyInstructor ? 'Approve (already Instructor)' : 'Approve') +
                    '</button>' +
                    '<button class="btn btn-danger btn-sm" data-action="reject-request" data-id="' + r.id + '">Reject</button>' +
                '</div></td>' +
            '</tr>';
        });

        html += '</tbody></table>';
        card.innerHTML = html;
    }

    function moduleCount(slug) {
        try {
            var raw = JSON.parse(localStorage.getItem('learnova_curriculum_' + slug) || 'null');
            if (raw && Array.isArray(raw.modules)) return raw.modules.length;
        } catch (err) { /* ignore */ }
        return 0;
    }

    function renderCourseModeration() {
        var card = document.getElementById('courseModerationCard');
        if (!card) return;

        var courses = readLS(COURSES_KEY, []);

        if (!courses.length) {
            card.innerHTML = '<div class="table-message">No courses in the system yet. Instructors create them in the course editor.</div>';
            return;
        }

        var statusLabels = {};
        statusLabels[COURSE_STATUS.DRAFT] = 'Draft';
        statusLabels[COURSE_STATUS.PENDING] = 'Pending';
        statusLabels[COURSE_STATUS.PUBLISHED] = 'Published';

        var html = '<table class="data-table"><thead><tr>' +
            '<th>Course</th><th>Track</th><th>Modules</th><th>Status</th><th>Actions</th>' +
            '</tr></thead><tbody>';

        courses.forEach(function (c) {
            var status = c.status || COURSE_STATUS.DRAFT;
            html += '<tr>' +
                '<td><div class="user-name">' + esc(c.title) + '</div>' +
                    (c.instructorEmail ? '<div class="user-email">By ' + esc(c.instructorEmail) + '</div>' : '') + '</td>' +
                '<td><span class="track-badge">' + esc(c.track || '—') + '</span></td>' +
                '<td>' + moduleCount(c.slug) + '</td>' +
                '<td><span class="status-badge ' + status + '">' + (statusLabels[status] || 'Draft') + '</span></td>' +
                '<td><div class="table-actions">' +
                    (status === COURSE_STATUS.PENDING
                        ? '<button class="btn btn-primary btn-sm" data-action="publish-course" data-slug="' + esc(c.slug) + '">Publish</button>'
                        : '') +
                    '<button class="btn btn-danger btn-sm" data-action="delete-course" data-slug="' + esc(c.slug) + '">Delete</button>' +
                '</div></td>' +
            '</tr>';
        });

        html += '</tbody></table>';
        card.innerHTML = html;
    }

    function handleCourseAction(action, slug) {
        var courses = readLS(COURSES_KEY, []);
        var course = courses.filter(function (c) { return c.slug === slug; })[0];
        if (!course) {
            renderCourseModeration();
            return;
        }

        if (action === 'publish-course') {
            course.status = COURSE_STATUS.PUBLISHED;
            writeLS(COURSES_KEY, courses);
            if (course.instructorEmail) {
                pushNotification(course.instructorEmail, 'Your course "' + course.title + '" was published. Students can now enroll.');
            }
            alert('"' + course.title + '" was published and is now live.');
        } else if (action === 'delete-course') {
            if (confirm('Delete course "' + course.title + '"? This cannot be undone.')) {
                courses = courses.filter(function (c) { return c.slug !== slug; });
                writeLS(COURSES_KEY, courses);
                localStorage.removeItem('learnova_curriculum_' + slug);
                alert('"' + course.title + '" was deleted.');
            }
        }
        renderCourseModeration();
        renderStats();
    }

    document.addEventListener('DOMContentLoaded', function () {
        renderStats();
        renderRecentUsers();
        renderInstructorRequests();
        renderCourseModeration();

        document.addEventListener('click', function (e) {
            var btn = e.target.closest('[data-action]');
            if (!btn) return;

            var action = btn.getAttribute('data-action');
            var id = Number(btn.dataset.id);
            var slug = btn.getAttribute('data-slug');

            if (action === 'approve-request' || action === 'reject-request') {
                var requests = readLS(REQUESTS_KEY, []);
                var req = requests.filter(function (r) { return r.id === id; })[0];
                if (!req) return;

                req.status = action === 'approve-request' ? 'approved' : 'rejected';
                writeLS(REQUESTS_KEY, requests);

                var users = readLS(REGISTRY_KEY, []);
                var user = users.filter(function (u) { return u.email === req.email; })[0];
                if (action === 'approve-request') {
                    if (!user) {
                        var nextId = users.reduce(function (max, u) { return Math.max(max, u.id || 0); }, 0) + 1;
                        user = { id: nextId, name: req.name, email: req.email, password: 'password123', roles: ['Student'], status: 'active', joined: new Date().toISOString() };
                        users.push(user);
                    }
                    if ((user.roles || []).indexOf('Instructor') === -1) user.roles.push('Instructor');
                    writeLS(REGISTRY_KEY, users);
                    pushNotification(req.email, 'Your instructor request was approved. You can now create courses.');
                    alert(req.name + ' was approved as an Instructor.');
                } else {
                    pushNotification(req.email, 'Your instructor request was rejected by an admin.');
                    alert('Request from ' + req.name + ' was rejected.');
                }
                renderInstructorRequests();
                renderStats();
                renderRecentUsers();
            }

            if (action === 'publish-course' || action === 'delete-course') {
                handleCourseAction(action, slug);
            }
        });
    });
})();
