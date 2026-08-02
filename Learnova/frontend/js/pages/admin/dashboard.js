/* ==========================================================================
   Admin Dashboard (dashboard.html)
   Fully data-driven through LearnovaAdminApi / LearnovaCourseApi; no
   seeded demo data and no direct localStorage access.
   - Live stats from the shared registry, course store, and enroll flags.
   - Recent users from the shared registry (learnova_users), created by the
     auth mock (register / admin create-account). No seeding here.
   - Instructor requests to approve or reject (spec 1.3).
   - Course moderation to publish pending courses or delete any (spec 2.2).
   ========================================================================== */

(function () {
    'use strict';

    var COURSE_STATUS = LearnovaConstants.COURSE_STATUS;

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

    function renderStats() {
        LearnovaAdminApi.stats().then(function (stats) {
            setText('statTotalUsers', String(stats.users));
            setText('statInstructors', String(stats.instructors));
            setText('statActiveCourses', String(stats.activeCourses));
            setText('statEnrollments', String(stats.enrollments));
        }).catch(function () { /* keep last values */ });
    }

    function setText(id, value) {
        var node = document.getElementById(id);
        if (node) node.textContent = value;
    }

    function renderRecentUsers() {
        var tbody = document.querySelector('#recentUsersTable tbody');
        if (!tbody) return;

        LearnovaAdminApi.listUsers().then(function (users) {
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
        }).catch(function () { /* ignore */ });
    }

    function renderInstructorRequests() {
        var card = document.getElementById('instructorRequestsCard');
        if (!card) return;

        LearnovaAdminApi.listInstructorRequests().then(function (requests) {
            var pending = (requests || []).filter(function (r) { return r.status === 'pending'; });

            if (!pending.length) {
                card.innerHTML = '<div class="table-message">No pending instructor requests.</div>';
                return;
            }

            var html = '<table class="data-table"><thead><tr>' +
                '<th>Name</th><th>Email</th><th>Requested</th><th>Status</th><th>Actions</th>' +
                '</tr></thead><tbody>';

            pending.forEach(function (r) {
                html += '<tr>' +
                    '<td><div class="user-cell"><div class="user-avatar">' + initialsOf(r.name) + '</div>' +
                    '<div><div class="user-name">' + esc(r.name) + '</div>' +
                    '<div class="user-email">' + esc(r.note || '') + '</div></div></div></td>' +
                    '<td>' + esc(r.email) + '</td>' +
                    '<td>' + formatDate(r.created_at || r.requestedAt) + '</td>' +
                    '<td><span class="status-badge pending">Pending</span></td>' +
                    '<td><div class="table-actions">' +
                        '<button class="btn btn-primary btn-sm" data-action="approve-request" data-id="' + r.id + '">Approve</button>' +
                        '<button class="btn btn-danger btn-sm" data-action="reject-request" data-id="' + r.id + '">Reject</button>' +
                    '</div></td>' +
                '</tr>';
            });

            html += '</tbody></table>';
            card.innerHTML = html;
        }).catch(function () { /* ignore */ });
    }

    function moduleCount(slug) {
        return LearnovaCourseApi.getCurriculum(slug).then(function (curriculum) {
            return (curriculum && curriculum.modules) ? curriculum.modules.length : 0;
        }).catch(function () { return 0; });
    }

    function renderCourseModeration() {
        var card = document.getElementById('courseModerationCard');
        if (!card) return;

        LearnovaAdminApi.listCourses().then(function (courses) {
            if (!courses.length) {
                card.innerHTML = '<div class="table-message">No courses in the system yet. Instructors create them in the course editor.</div>';
                return;
            }

            var statusLabels = {};
            statusLabels[COURSE_STATUS.DRAFT] = 'Draft';
            statusLabels[COURSE_STATUS.PENDING] = 'Pending';
            statusLabels[COURSE_STATUS.PUBLISHED] = 'Published';

            var counts = courses.map(function (c) { return moduleCount(c.slug); });

            return Promise.all(counts).then(function (moduleCounts) {
                var html = '<table class="data-table"><thead><tr>' +
                    '<th>Course</th><th>Track</th><th>Modules</th><th>Status</th><th>Actions</th>' +
                    '</tr></thead><tbody>';

                courses.forEach(function (c, index) {
                    var status = c.status || COURSE_STATUS.DRAFT;
                    html += '<tr>' +
                        '<td><div class="user-name">' + esc(c.title) + '</div>' +
                            (c.instructorEmail ? '<div class="user-email">By ' + esc(c.instructorEmail) + '</div>' : '') + '</td>' +
                        '<td><span class="track-badge">' + esc(c.track || '—') + '</span></td>' +
                        '<td>' + moduleCounts[index] + '</td>' +
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
            });
        }).catch(function () { /* ignore */ });
    }

    function handleCourseAction(action, slug) {
        if (action === 'publish-course') {
            LearnovaAdminApi.publishCourse(slug).then(function (course) {
                LearnovaToast.success('"' + course.title + '" was published and is now live.');
                refreshAll();
            }).catch(function (err) {
                LearnovaToast.error((err && err.message) || 'Could not publish course.');
            });
        } else if (action === 'delete-course') {
            LearnovaCourseApi.list().then(function (courses) {
                var course = courses.filter(function (c) { return c.slug === slug; })[0];
                if (!course) return;
                return LearnovaConfirm.ask('Delete course "' + course.title + '"? This cannot be undone.').then(function (ok) {
                    if (!ok) return;
                    return LearnovaCourseApi.remove(slug).then(function () {
                        LearnovaToast.success('"' + course.title + '" was deleted.');
                        refreshAll();
                    }).catch(function (err) {
                        LearnovaToast.error((err && err.message) || 'Could not delete course.');
                    });
                });
            });
        }
    }

    function handleRequestAction(action, id) {
        var call = action === 'approve-request'
            ? LearnovaAdminApi.approveInstructorRequest(id)
            : LearnovaAdminApi.rejectInstructorRequest(id);
        call.then(function () {
            refreshAll();
        }).catch(function (err) {
            LearnovaToast.error((err && err.message) || 'Could not update the request.');
        });
    }

    function refreshAll() {
        renderStats();
        renderRecentUsers();
        renderInstructorRequests();
        renderCourseModeration();
    }

    document.addEventListener('DOMContentLoaded', function () {
        refreshAll();

        document.addEventListener('click', function (e) {
            var btn = e.target.closest('[data-action]');
            if (!btn) return;

            var action = btn.getAttribute('data-action');

            if (action === 'approve-request' || action === 'reject-request') {
                handleRequestAction(action, btn.dataset.id);
                return;
            }
            if (action === 'publish-course' || action === 'delete-course') {
                handleCourseAction(action, btn.getAttribute('data-slug'));
            }
        });
    });
})();
