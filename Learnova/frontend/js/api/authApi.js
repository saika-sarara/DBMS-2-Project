/* ==========================================================================
   Learnova Auth API (window.LearnovaAuthApi)
   ========================================================================== */

window.LearnovaAuthApi = (function () {
    'use strict';

    /* Backend wraps responses in {success, message, data, timestamp}; the
       offline mock returns the payload directly. Unwrap either shape. */
    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function login(credentials) {
        return unwrap(LearnovaApiClient.post('/auth/login', credentials));
    }

    function register(payload) {
        return unwrap(LearnovaApiClient.post('/auth/register', payload));
    }

    function me() {
        return unwrap(LearnovaApiClient.get('/auth/me'));
    }

    /* There is no server-side logout endpoint (JWT is stateless). Logout is
       purely client-side: clear the stored session/token. */
    function logout() {
        LearnovaSession.clear();
        return Promise.resolve();
    }

    return {
        login: login,
        register: register,
        me: me,
        logout: logout
    };
})();
