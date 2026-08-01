/* ==========================================================================
   Learnova Auth API (window.LearnovaAuthApi)
   ========================================================================== */

window.LearnovaAuthApi = (function () {
    'use strict';

    function login(credentials) {
        return LearnovaApiClient.post('/auth/login', credentials);
    }

    function register(payload) {
        return LearnovaApiClient.post('/auth/register', payload);
    }

    function logout() {
        return LearnovaApiClient.post('/auth/logout');
    }

    return {
        login: login,
        register: register,
        logout: logout
    };
})();
