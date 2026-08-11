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

    /* Guard against binding the overlay click handlers multiple times when both
       login.js and register.js are included on the same page. Mark the card so
       other script instances skip attaching duplicate listeners. */
    if (authCard && !authCard.dataset.overlayBound && signUpBtn && signInBtn) {
        signUpBtn.addEventListener('click', function () {
            authCard.classList.add('right-panel-active');
        });
        signInBtn.addEventListener('click', function () {
            authCard.classList.remove('right-panel-active');
        });
        authCard.dataset.overlayBound = '1';
    }

    var registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', function (event) {
            event.preventDefault();

            var firstName = document.getElementById('registerFirstName').value.trim();
            var lastName = document.getElementById('registerLastName').value.trim();
            var email = document.getElementById('registerEmail').value.trim().toLowerCase();
            var password = document.getElementById('registerPassword').value;

            var fullName = (firstName + ' ' + lastName).trim();

            /* Send the name in every shape both the Spring backend and the
               offline mock understand (backend: fullName || name ||
               firstName+lastName; mock: name). */
            LearnovaAuthApi.register({
                name: fullName,
                fullName: fullName,
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password
            }).then(function () {
                LearnovaToast.success('Account created as a Student. Sign in to start learning — ' +
                    'you can request the Instructor role later from your dashboard.');

                if (authCard) authCard.classList.remove('right-panel-active');
                registerForm.reset();
            }).catch(function (err) {
                LearnovaToast.error((err && err.message) || 'Unable to create your account. Please try again.');
            });
        });
    }
});
