/* ==========================================================================
   Learnova Register (pages/auth/register.html)
   Frontend-only demo registration flow:
   - Self-registration always creates a Student account (spec 1.3: becoming
     an Instructor is NOT self-serve).
   - Accounts start active; instructor role is only granted after an Admin
     approves an instructor_request.
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

    var registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', function (event) {
            event.preventDefault();

            var inputs = registerForm.querySelectorAll('input');
            var firstName = inputs[0].value.trim();
            var lastName = inputs[1].value.trim();
            var email = inputs[2].value.trim().toLowerCase();
            var password = inputs[3].value;

            if (!firstName || !lastName || !LearnovaValidators.isEmail(email)) {
                alert('Please fill in your name and a valid email address.');
                return;
            }
            if (password.length < 8) {
                alert('Password must be at least 8 characters.');
                return;
            }

            var users = JSON.parse(localStorage.getItem(REGISTRY_KEY) || '[]');
            var exists = users.some(function (u) { return u.email.toLowerCase() === email; });
            if (exists) {
                alert('An account with this email already exists.');
                return;
            }

            users.push({
                id: users.length + 1,
                name: firstName + ' ' + lastName,
                email: email,
                password: password,
                roles: [LearnovaConstants.ROLES.STUDENT],
                status: LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
                joined: 'Aug 2026'
            });
            localStorage.setItem(REGISTRY_KEY, JSON.stringify(users));

            alert('Account created as a Student. Sign in to start learning — ' +
                'you can request the Instructor role later from your dashboard.');

            if (authCard) authCard.classList.remove('right-panel-active');
            registerForm.reset();
        });
    }
});
