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
            var inputs = loginForm.querySelectorAll('input');
            var email = inputs[0].value.trim().toLowerCase();
            var password = inputs[1].value;

            LearnovaAuthApi.login({ email: email, password: password })
                .then(function (user) {
                    LearnovaSession.set(user);
                    LearnovaRouteGuard.redirectToDashboard();
                })
                .catch(function (err) {
                    alert((err && err.message) || 'Unable to sign in. Please try again.');
                });
        });
    }
});
