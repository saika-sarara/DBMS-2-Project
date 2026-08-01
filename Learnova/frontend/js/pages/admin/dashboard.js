/* ==========================================================================
   Admin Dashboard (dashboard.html)
   Recent users (from the shared registry), instructor requests to approve or
   reject (spec 1.3), and course moderation to publish pending courses or
   delete any course (spec 2.2).
   ========================================================================== */

var REGISTRY_KEY = window.LearnovaConstants ? LearnovaConstants.USERS_KEY : 'learnova_users';
var REQUESTS_KEY = window.LearnovaConstants ? LearnovaConstants.INSTRUCTOR_REQUEST_KEY : 'learnova_instructor_requests';
var COURSES_KEY = window.LearnovaConstants ? LearnovaConstants.COURSES_KEY : 'learnova_courses';
var NOTIFICATIONS_KEY = window.LearnovaConstants ? LearnovaConstants.NOTIFICATIONS_KEY : 'learnova_notifications';

var COURSE_STATUS = window.LearnovaConstants ? LearnovaConstants.COURSE_STATUS : {
    DRAFT: 'draft',
    PENDING: 'pending',
    PUBLISHED: 'published'
};

var SEED_USERS = [
    { id: 1, name: 'Sarah Jenkins', email: 'sarah.j@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Mar 2026' },
    { id: 2, name: 'David Miller', email: 'david.m@example.com', password: 'password123', roles: ['Instructor'], status: 'active', joined: 'Jan 2026' },
    { id: 3, name: 'Omar Haddad', email: 'omar.h@example.com', password: 'password123', roles: ['Admin'], status: 'active', joined: 'Dec 2025' },
    { id: 4, name: 'Priya Sharma', email: 'priya.s@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Apr 2026' },
    { id: 5, name: 'Maya Patel', email: 'maya.p@example.com', password: 'password123', roles: ['Student'], status: 'suspended', joined: 'Nov 2025' },
    { id: 6, name: 'Lena Fischer', email: 'lena.f@example.com', password: 'password123', roles: ['Student'], status: 'banned', joined: 'Oct 2025' }
];

var SEED_REQUESTS = [
    { id: 1, name: 'Priya Sharma', email: 'priya.s@example.com', requestedAt: 'Jul 2026', status: 'pending', note: 'Wants to teach Data Science courses.' },
    { id: 2, name: 'Alex Chen', email: 'alex.c@example.com', requestedAt: 'Jul 2026', status: 'pending', note: 'Wants to teach Frontend Dev courses.' }
];

var SEED_COURSES = [
    { id: 1, title: 'Database Design Fundamentals', track: 'Database Engineer', modules: 4, status: 'pending', instructorEmail: 'david.m@example.com' },
    { id: 2, title: 'Modern React & TypeScript', track: 'Frontend Dev', modules: 3, status: 'published', instructorEmail: 'david.m@example.com' },
    { id: 3, title: 'Python for Data Science', track: 'Data Science', modules: 5, status: 'draft', instructorEmail: 'david.m@example.com' },
    { id: 4, title: 'Intro to Neo4j Graph Databases', track: 'Standalone', modules: 2, status: 'draft', instructorEmail: 'david.m@example.com' }
];

function readLS(key, seed) {
    var raw = localStorage.getItem(key);
    if (raw) {
        try { return JSON.parse(raw); } catch (err) { /* fall through */ }
    }
    localStorage.setItem(key, JSON.stringify(seed));
    return seed.slice();
}

function writeLS(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
}

function initialsOf(name) {
    var parts = name.trim().split(/\s+/);
    return (parts[0] ? parts[0][0] : '') + (parts[1] ? parts[1][0] : '');
}

function rolesLabel(roles) {
    if (Array.isArray(roles) && roles.length) return roles.join(' + ');
    return 'Student';
}

function pushNotification(email, message) {
    var notifications = readLS(NOTIFICATIONS_KEY, []);
    notifications.unshift({
        email: email,
        message: message,
        time: new Date().toLocaleString(),
        read: false
    });
    writeLS(NOTIFICATIONS_KEY, notifications);
}

function renderRecentUsers() {
    var tbody = document.querySelector('#recentUsersTable tbody');
    if (!tbody) return;

    var users = readLS(REGISTRY_KEY, SEED_USERS);

    users.forEach(function (user) {
        var row = document.createElement('tr');
        var statusClass = user.status || 'active';
        var statusLabel = { active: 'Active', suspended: 'Suspended', banned: 'Banned' }[statusClass] || 'Active';

        row.innerHTML =
            '<td>' +
                '<div class="user-cell">' +
                    '<div class="user-avatar">' + initialsOf(user.name) + '</div>' +
                    '<div>' +
                        '<div class="user-name">' + user.name + '</div>' +
                        '<div class="user-email">' + user.email + '</div>' +
                    '</div>' +
                '</div>' +
            '</td>' +
            '<td><span class="track-badge">' + rolesLabel(user.roles) + '</span></td>' +
            '<td><span class="status-badge ' + statusClass + '">' + statusLabel + '</span></td>' +
            '<td>' + (user.joined || 'Aug 2026') + '</td>';

        tbody.appendChild(row);
    });
}

function renderInstructorRequests() {
    var card = document.getElementById('instructorRequestsCard');
    if (!card) return;

    var requests = readLS(REQUESTS_KEY, SEED_REQUESTS);
    var pending = requests.filter(function (r) { return r.status === 'pending'; });
    var users = readLS(REGISTRY_KEY, SEED_USERS);

    if (pending.length === 0) {
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
            '<div><div class="user-name">' + r.name + '</div>' +
            '<div class="user-email">' + r.note + '</div></div></div></td>' +
            '<td>' + r.email + '</td>' +
            '<td>' + r.requestedAt + '</td>' +
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

function renderCourseModeration() {
    var card = document.getElementById('courseModerationCard');
    if (!card) return;

    var courses = readLS(COURSES_KEY, SEED_COURSES);

    if (courses.length === 0) {
        card.innerHTML = '<div class="table-message">No courses in the system.</div>';
        return;
    }

    var html = '<table class="data-table"><thead><tr>' +
        '<th>Course</th><th>Track</th><th>Modules</th><th>Status</th><th>Actions</th>' +
        '</tr></thead><tbody>';

    var statusLabels = {};
    statusLabels[COURSE_STATUS.DRAFT] = 'Draft';
    statusLabels[COURSE_STATUS.PENDING] = 'Pending';
    statusLabels[COURSE_STATUS.PUBLISHED] = 'Published';

    courses.forEach(function (c) {
        var status = c.status || COURSE_STATUS.DRAFT;
        html += '<tr>' +
            '<td><div class="user-name">' + c.title + '</div></td>' +
            '<td><span class="track-badge">' + c.track + '</span></td>' +
            '<td>' + c.modules + '</td>' +
            '<td><span class="status-badge ' + status + '">' + (statusLabels[status] || 'Draft') + '</span></td>' +
            '<td><div class="table-actions">' +
                (status === COURSE_STATUS.PENDING
                    ? '<button class="btn btn-primary btn-sm" data-action="publish-course" data-id="' + c.id + '">Publish</button>'
                    : '') +
                '<button class="btn btn-danger btn-sm" data-action="delete-course" data-id="' + c.id + '">Delete</button>' +
            '</div></td>' +
        '</tr>';
    });

    html += '</tbody></table>';
    card.innerHTML = html;
}

document.addEventListener('DOMContentLoaded', function () {
    renderRecentUsers();
    renderInstructorRequests();
    renderCourseModeration();

    document.addEventListener('click', function (e) {
        var btn = e.target.closest('[data-action]');
        if (!btn) return;

        var action = btn.getAttribute('data-action');
        var id = Number(btn.dataset.id);

        if (action === 'approve-request' || action === 'reject-request') {
            var requests = readLS(REQUESTS_KEY, SEED_REQUESTS);
            var req = requests.find(function (r) { return r.id === id; });
            if (!req) return;

            req.status = action === 'approve-request' ? 'approved' : 'rejected';
            writeLS(REQUESTS_KEY, requests);

            var users = readLS(REGISTRY_KEY, SEED_USERS);
            var user = users.find(function (u) { return u.email === req.email; });
            if (action === 'approve-request') {
                if (!user) {
                    var nextId = users.reduce(function (max, u) { return Math.max(max, u.id); }, 0) + 1;
                    user = { id: nextId, name: req.name, email: req.email, password: 'password123', roles: ['Student'], status: 'active', joined: 'Aug 2026' };
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
        }

        if (action === 'publish-course' || action === 'delete-course') {
            var courses = readLS(COURSES_KEY, SEED_COURSES);

            if (action === 'publish-course') {
                var course = courses.find(function (c) { return c.id === id; });
                if (course) {
                    course.status = COURSE_STATUS.PUBLISHED;
                    writeLS(COURSES_KEY, courses);
                    pushNotification(course.instructorEmail, 'Your course "' + course.title + '" was published. Students can now enroll.');
                    alert('"' + course.title + '" was published and is now live.');
                }
            } else if (action === 'delete-course') {
                var target = courses.find(function (c) { return c.id === id; });
                if (target && confirm('Delete course "' + target.title + '"? This cannot be undone.')) {
                    courses = courses.filter(function (c) { return c.id !== id; });
                    writeLS(COURSES_KEY, courses);
                    alert('"' + target.title + '" was deleted.');
                }
            }
            renderCourseModeration();
        }
    });
});
