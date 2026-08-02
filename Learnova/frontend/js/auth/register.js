/* ==========================================================================
   Learnova Register (pages/auth/register.html)
   Self-registration through the API layer (LearnovaAuthApi); always creates
   a Student account (spec 1.3: becoming an Instructor is NOT self-serve).
   Validation and duplicate-email checks are enforced server-side / by the
   offline mock adapter.
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

    var registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', function (event) {
            event.preventDefault();

            var inputs = registerForm.querySelectorAll('input');
            var firstName = inputs[0].value.trim();
            var lastName = inputs[1].value.trim();
            var email = inputs[2].value.trim().toLowerCase();
            var password = inputs[3].value;

            LearnovaAuthApi.register({
                name: (firstName + ' ' + lastName).trim(),
                email: email,
                password: password
            }).then(function () {
                alert('Account created as a Student. Sign in to start learning — ' +
                    'you can request the Instructor role later from your dashboard.');

                if (authCard) authCard.classList.remove('right-panel-active');
                registerForm.reset();
            }).catch(function (err) {
                alert((err && err.message) || 'Unable to create your account. Please try again.');
            });
        });
    }
});
