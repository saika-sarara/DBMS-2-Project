/* ==========================================================================
   Admin User Management (user-management.html)
   Uses LearnovaAdminApi over the shared user registry (learnova_users).
   Supports multi-role users (spec 1.2) and account statuses active /
   suspended / banned (spec 1.1). Admins can create accounts directly
   (spec 6.2) and change a user's role or status.
   ========================================================================== */

(function () {
    'use strict';

    var STATUS_LABELS = {};
    STATUS_LABELS[LearnovaConstants.ACCOUNT_STATUS.ACTIVE] = 'Active';
    STATUS_LABELS[LearnovaConstants.ACCOUNT_STATUS.SUSPENDED] = 'Suspended';
    STATUS_LABELS[LearnovaConstants.ACCOUNT_STATUS.BANNED] = 'Banned';

    function rolesLabel(roles) {
        if (Array.isArray(roles) && roles.length) return roles.join(' + ');
        return 'Student';
    }

    function initialsOf(name) {
        var parts = String(name || '').trim().split(/\s+/);
        return (parts[0] ? parts[0][0] : '') + (parts[1] ? parts[1][0] : '');
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function isInstructor(u) {
        return (u.roles || []).indexOf(LearnovaConstants.ROLES.INSTRUCTOR) !== -1;
    }

    function statusOptions(selected) {
        return [
            LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
            LearnovaConstants.ACCOUNT_STATUS.SUSPENDED,
            LearnovaConstants.ACCOUNT_STATUS.BANNED
        ].map(function (s) {
            return '<option value="' + s + '"' + (s === selected ? ' selected' : '') + '>' +
                STATUS_LABELS[s] + '</option>';
        }).join('');
    }

    function render(users, tbody, searchInput, roleFilter, statusFilter) {
        var query = searchInput.value.trim().toLowerCase();
        var role = roleFilter.value;
        var status = statusFilter.value;

        var filtered = users.filter(function (u) {
            var matchesQuery = !query ||
                u.name.toLowerCase().indexOf(query) !== -1 ||
                u.email.toLowerCase().indexOf(query) !== -1;
            var matchesRole = !role || (u.roles || []).indexOf(role) !== -1;
            var matchesStatus = !status || u.status === status;
            return matchesQuery && matchesRole && matchesStatus;
        });

        tbody.innerHTML = '';

        if (filtered.length === 0) {
            var emptyRow = document.createElement('tr');
            emptyRow.innerHTML = '<td colspan="5" style="text-align:center; color:#5f5f7a; padding:2rem;">No users match your filters.</td>';
            tbody.appendChild(emptyRow);
            return;
        }

        filtered.forEach(function (u) {
            var row = document.createElement('tr');
            row.dataset.id = u.id;

            row.innerHTML =
                '<td>' +
                    '<div class="user-cell">' +
                        '<div class="user-avatar">' + initialsOf(u.name) + '</div>' +
                        '<div>' +
                            '<div class="user-name">' + esc(u.name) + '</div>' +
                            '<div class="user-email">' + esc(u.email) + '</div>' +
                        '</div>' +
                    '</div>' +
                '</td>' +
                '<td><span class="track-badge">' + esc(rolesLabel(u.roles)) + '</span></td>' +
                '<td><span class="status-badge ' + u.status + '">' + (STATUS_LABELS[u.status] || 'Active') + '</span></td>' +
                '<td>' + esc(u.joined) + '</td>' +
                '<td><div class="table-actions">' +
                    '<select class="status-select" data-id="' + u.id + '">' +
                        statusOptions(u.status) +
                    '</select>' +
                    '<button class="btn btn-ghost btn-sm" data-action="promote" data-id="' + u.id + '">' +
                        (isInstructor(u) ? 'Revoke Instructor' : 'Make Instructor') +
                    '</button>' +
                    '<button class="btn btn-danger btn-sm" data-action="delete" data-id="' + u.id + '">Delete</button>' +
                '</div></td>';

            tbody.appendChild(row);
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var tbody = document.querySelector('#usersTable tbody');
        var searchInput = document.getElementById('userSearch');
        var roleFilter = document.getElementById('roleFilter');
        var statusFilter = document.getElementById('statusFilter');
        if (!tbody || !searchInput || !roleFilter || !statusFilter) return;

        var users = [];

        function rerender() {
            render(users, tbody, searchInput, roleFilter, statusFilter);
        }

        function load() {
            LearnovaAdminApi.listUsers().then(function (list) {
                users = list || [];
                rerender();
            }).catch(function () { /* keep last list */ });
        }

        tbody.addEventListener('change', function (e) {
            if (e.target.classList.contains('status-select')) {
                var id = e.target.dataset.id;
                var user = users.filter(function (u) { return String(u.id) === String(id); })[0];
                if (!user) return;
                LearnovaAdminApi.setUserStatus(id, e.target.value).then(function () {
                    load();
                    alert(user.name + '\'s status changed to ' + (STATUS_LABELS[e.target.value] || e.target.value) + '.');
                }).catch(function (err) {
                    alert((err && err.message) || 'Could not change status.');
                });
            }
        });

        tbody.addEventListener('click', function (e) {
            var btn = e.target.closest('[data-action]');
            if (!btn) return;
            var id = btn.dataset.id;
            var user = users.filter(function (u) { return String(u.id) === String(id); })[0];
            if (!user) return;

            if (btn.dataset.action === 'promote') {
                var role = isInstructor(user) ? LearnovaConstants.ROLES.STUDENT : LearnovaConstants.ROLES.INSTRUCTOR;
                LearnovaAdminApi.updateUserRole(id, role).then(function () {
                    load();
                    if (isInstructor(user)) {
                        alert(user.name + ' is no longer an Instructor.');
                    } else {
                        alert(user.name + ' now holds the Instructor role.');
                    }
                }).catch(function (err) {
                    alert((err && err.message) || 'Could not update the role.');
                });
            } else if (btn.dataset.action === 'delete') {
                if (confirm('Delete user ' + user.name + '? This cannot be undone.')) {
                    LearnovaAdminApi.deleteUser(id).then(function () {
                        load();
                    }).catch(function (err) {
                        alert((err && err.message) || 'Could not delete user.');
                    });
                }
            }
        });

        var createBtn = document.getElementById('createUserBtn');
        if (createBtn) {
            createBtn.addEventListener('click', function () {
                var nameInput = document.getElementById('newUserName');
                var emailInput = document.getElementById('newUserEmail');
                var passInput = document.getElementById('newUserPassword');
                var roleSelect = document.getElementById('newUserRole');

                var name = nameInput.value.trim();
                var email = emailInput.value.trim().toLowerCase();
                var password = passInput.value;

                if (!name || !email || password.length < 8) {
                    alert('Fill in name, a valid email, and a password of at least 8 characters.');
                    return;
                }

                LearnovaAdminApi.createUser({
                    name: name,
                    email: email,
                    password: password,
                    role: roleSelect.value
                }).then(function (created) {
                    nameInput.value = '';
                    emailInput.value = '';
                    passInput.value = '';
                    alert('Account created for ' + created.name + ' with role ' + roleSelect.value + '.');
                    load();
                }).catch(function (err) {
                    alert((err && err.message) || 'Could not create the account.');
                });
            });
        }

        searchInput.addEventListener('input', rerender);
        roleFilter.addEventListener('change', rerender);
        statusFilter.addEventListener('change', rerender);

        load();
    });
})();
