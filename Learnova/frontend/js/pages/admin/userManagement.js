/* ==========================================================================
   Admin User Management (user-management.html)
   Reads/writes the shared user registry (USERS_KEY) used by login/register.
   Supports multi-role users (spec 1.2) and account statuses active /
   suspended / banned (spec 1.1). Admins can create accounts directly
   (spec 6.2) and change a user's role or status.
   ========================================================================== */

var REGISTRY_KEY = window.LearnovaConstants ? LearnovaConstants.USERS_KEY : 'learnova_users';

var STATUS_LIST = window.LearnovaConstants ? LearnovaConstants.ACCOUNT_STATUS : {
    ACTIVE: 'active',
    SUSPENDED: 'suspended',
    BANNED: 'banned'
};

var STATUS_LABELS = {};
STATUS_LABELS[STATUS_LIST.ACTIVE] = 'Active';
STATUS_LABELS[STATUS_LIST.SUSPENDED] = 'Suspended';
STATUS_LABELS[STATUS_LIST.BANNED] = 'Banned';

var SEED_USERS = [
    { id: 1, name: 'Sarah Jenkins', email: 'sarah.j@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Mar 2026' },
    { id: 2, name: 'David Miller', email: 'david.m@example.com', password: 'password123', roles: ['Instructor'], status: 'active', joined: 'Jan 2026' },
    { id: 3, name: 'Omar Haddad', email: 'omar.h@example.com', password: 'password123', roles: ['Admin'], status: 'active', joined: 'Dec 2025' },
    { id: 4, name: 'Priya Sharma', email: 'priya.s@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Apr 2026' },
    { id: 5, name: 'Maya Patel', email: 'maya.p@example.com', password: 'password123', roles: ['Student'], status: 'suspended', joined: 'Nov 2025' },
    { id: 6, name: 'Lena Fischer', email: 'lena.f@example.com', password: 'password123', roles: ['Student'], status: 'banned', joined: 'Oct 2025' }
];

function readRegistry() {
    var raw = localStorage.getItem(REGISTRY_KEY);
    if (raw) {
        try { return JSON.parse(raw); } catch (err) { /* fall through */ }
    }
    localStorage.setItem(REGISTRY_KEY, JSON.stringify(SEED_USERS));
    return SEED_USERS.slice();
}

function writeRegistry(users) {
    localStorage.setItem(REGISTRY_KEY, JSON.stringify(users));
}

function rolesLabel(roles) {
    if (Array.isArray(roles) && roles.length) return roles.join(' + ');
    return 'Student';
}

function initialsOf(name) {
    var parts = name.trim().split(/\s+/);
    return (parts[0] ? parts[0][0] : '') + (parts[1] ? parts[1][0] : '');
}

function render(users, tbody, searchInput, roleFilter, statusFilter) {
    var query = searchInput.value.trim().toLowerCase();
    var role = roleFilter.value;
    var status = statusFilter.value;

    var filtered = users.filter(function (u) {
        var matchesQuery = !query ||
            u.name.toLowerCase().indexOf(query) !== -1 ||
            u.email.toLowerCase().indexOf(query) !== -1;
        var primary = u.roles && u.roles.length ? u.roles[0] : 'Student';
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
                        '<div class="user-name">' + u.name + '</div>' +
                        '<div class="user-email">' + u.email + '</div>' +
                    '</div>' +
                '</div>' +
            '</td>' +
            '<td><span class="track-badge">' + rolesLabel(u.roles) + '</span></td>' +
            '<td><span class="status-badge ' + u.status + '">' + (STATUS_LABELS[u.status] || 'Active') + '</span></td>' +
            '<td>' + u.joined + '</td>' +
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

function statusOptions(selected) {
    return [STATUS_LIST.ACTIVE, STATUS_LIST.SUSPENDED, STATUS_LIST.BANNED].map(function (s) {
        return '<option value="' + s + '"' + (s === selected ? ' selected' : '') + '>' +
            STATUS_LABELS[s] + '</option>';
    }).join('');
}

function isInstructor(u) {
    return (u.roles || []).indexOf('Instructor') !== -1;
}

document.addEventListener('DOMContentLoaded', function () {
    var tbody = document.querySelector('#usersTable tbody');
    var searchInput = document.getElementById('userSearch');
    var roleFilter = document.getElementById('roleFilter');
    var statusFilter = document.getElementById('statusFilter');
    if (!tbody || !searchInput || !roleFilter || !statusFilter) return;

    var users = readRegistry();

    function rerender() {
        render(users, tbody, searchInput, roleFilter, statusFilter);
    }

    tbody.addEventListener('change', function (e) {
        if (e.target.classList.contains('status-select')) {
            var id = Number(e.target.dataset.id);
            var user = users.find(function (u) { return u.id === id; });
            if (user) {
                user.status = e.target.value;
                writeRegistry(users);
                alert(user.name + '\'s status changed to ' + (STATUS_LABELS[user.status] || user.status) + '.');
            }
        }
    });

    tbody.addEventListener('click', function (e) {
        var btn = e.target.closest('[data-action]');
        if (!btn) return;
        var id = Number(btn.dataset.id);
        var user = users.find(function (u) { return u.id === id; });
        if (!user) return;

        if (btn.dataset.action === 'promote') {
            if (isInstructor(user)) {
                user.roles = user.roles.filter(function (r) { return r !== 'Instructor'; });
                if (!user.roles.length) user.roles = ['Student'];
                alert(user.name + ' is no longer an Instructor.');
            } else {
                if (user.roles.indexOf('Instructor') === -1) user.roles.push('Instructor');
                alert(user.name + ' now holds the Instructor role.');
            }
            writeRegistry(users);
        } else if (btn.dataset.action === 'delete') {
            if (confirm('Delete user ' + user.name + '? This cannot be undone.')) {
                users = users.filter(function (u) { return u.id !== id; });
                writeRegistry(users);
            }
        }
        rerender();
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
            if (users.some(function (u) { return u.email === email; })) {
                alert('An account with that email already exists.');
                return;
            }

            var id = users.reduce(function (max, u) { return Math.max(max, u.id); }, 0) + 1;
            users.push({
                id: id,
                name: name,
                email: email,
                password: password,
                roles: [roleSelect.value],
                status: STATUS_LIST.ACTIVE,
                joined: 'Aug 2026'
            });
            writeRegistry(users);
            nameInput.value = '';
            emailInput.value = '';
            passInput.value = '';
            alert('Account created for ' + name + ' with role ' + roleSelect.value + '.');
            rerender();
        });
    }

    searchInput.addEventListener('input', rerender);
    roleFilter.addEventListener('change', rerender);
    statusFilter.addEventListener('change', rerender);

    rerender();
});
