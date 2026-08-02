/* ==========================================================================
   Learnova Login (pages/auth/login.html)
   Signs a user in through the API layer (LearnovaAuthApi). Requests go to
   the real backend when available (LearnovaApiClient fetch) and fall back
   to the offline mock adapter on network errors. Account status blocking
   (suspended / banned) is enforced server-side / by the mock.
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

    var loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', function (event) {
            event.preventDefault();

            var emailInput = document.getElementById('loginEmail');
            var passwordInput = document.getElementById('loginPassword');
            var email = (emailInput && emailInput.value || '').trim().toLowerCase();
            var password = (passwordInput && passwordInput.value) || '';

            if (!email || !password) {
                LearnovaToast.error('Please enter your email and password.');
                return;
            }

            LearnovaAuthApi.login({ email: email, password: password })
                .then(function (user) {
                    LearnovaSession.set(user);
                    goAfterLogin();
                })
                .catch(function (err) {
                    LearnovaToast.error((err && err.message) || 'Unable to sign in. Please try again.');
                });
        });
    }

    /* After a successful login, return to the page the user was trying to
       reach (the ?redirect= param set by LearnovaRouteGuard.protectPage),
       otherwise go to the role dashboard. */
    function goAfterLogin() {
        var redirect = new URLSearchParams(window.location.search).get('redirect');
        if (redirect && redirect.indexOf('/pages/') !== -1 && redirect.indexOf('login.html') === -1) {
            var base = LearnovaRouteGuard.pageUrl('').replace(/\/pages\/$/, '');
            var target = redirect.charAt(0) === '/' ? redirect : base + '/' + redirect;
            window.location.href = target;
            return;
        }
        LearnovaRouteGuard.redirectToDashboard();
    }
});
