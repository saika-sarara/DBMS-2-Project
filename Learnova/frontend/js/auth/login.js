/* ==========================================================================
   Learnova Login (pages/auth/login.html)
   Frontend-only demo auth flow:
   - Mock user registry persisted in localStorage (USERS_KEY); the real
     backend stores bcrypt-hashed passwords.
   - Account statuses active / suspended / banned (spec 1.1). Suspended and
     banned users are blocked from signing in.
   - Role-based redirect via LearnovaRouteGuard (spec 1.2 RBAC).
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var authCard = document.getElementById('authCard');
    var signUpBtn = document.getElementById('signUpBtn');
    var signInBtn = document.getElementById('signInBtn');

    if (authCard && signUpBtn && signInBtn) {
        signUpBtn.addEventListener('click', function () {
            authCard.classList.add('right-panel-active');
        });
        signInBtn.addEventListener('click', function () {
            authCard.classList.remove('right-panel-active');
        });
    }

    var REGISTRY_KEY = LearnovaConstants.USERS_KEY;

    function seedUsers() {
        if (localStorage.getItem(REGISTRY_KEY)) return;
        var users = [
            { id: 1, name: 'Sarah Jenkins', email: 'sarah.j@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Mar 2026' },
            { id: 2, name: 'David Miller', email: 'david.m@example.com', password: 'password123', roles: ['Instructor'], status: 'active', joined: 'Jan 2026' },
            { id: 3, name: 'Omar Haddad', email: 'omar.h@example.com', password: 'password123', roles: ['Admin'], status: 'active', joined: 'Dec 2025' },
            { id: 4, name: 'Priya Sharma', email: 'priya.s@example.com', password: 'password123', roles: ['Student'], status: 'active', joined: 'Apr 2026' },
            { id: 5, name: 'Maya Patel', email: 'maya.p@example.com', password: 'password123', roles: ['Student'], status: 'suspended', joined: 'Nov 2025' },
            { id: 6, name: 'Lena Fischer', email: 'lena.f@example.com', password: 'password123', roles: ['Student'], status: 'banned', joined: 'Oct 2025' }
        ];
        localStorage.setItem(REGISTRY_KEY, JSON.stringify(users));
    }

    seedUsers();

    var loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', function (event) {
            event.preventDefault();
            var inputs = loginForm.querySelectorAll('input');
            var email = inputs[0].value.trim().toLowerCase();
            var password = inputs[1].value;

            var users = JSON.parse(localStorage.getItem(REGISTRY_KEY) || '[]');
            var user = users.filter(function (u) { return u.email.toLowerCase() === email; })[0];

            if (!user || user.password !== password) {
                alert('Invalid email or password. Hint: sarah.j@example.com / password123');
                return;
            }

            if (user.status === LearnovaConstants.ACCOUNT_STATUS.SUSPENDED ||
                user.status === LearnovaConstants.ACCOUNT_STATUS.BANNED) {
                alert('This account is ' + user.status + '. ' +
                    (user.status === 'suspended' ? 'Please contact support.' : 'Contact an administrator.'));
                return;
            }

            LearnovaSession.set({
                id: user.id,
                name: user.name,
                email: user.email,
                roles: user.roles,
                role: user.roles[0],
                status: user.status,
                token: 'demo-token-' + user.id
            });

            LearnovaRouteGuard.redirectToDashboard();
        });
    }
});
