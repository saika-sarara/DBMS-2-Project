/* ==========================================================================
   Learnova Certificate API (window.LearnovaCertificateApi)
   ========================================================================== */

window.LearnovaCertificateApi = (function () {
    'use strict';

    function listByUser() {
        return LearnovaApiClient.get('/certificates/mine');
    }

    function generate(courseId) {
        return LearnovaApiClient.post('/certificates', { courseId: courseId });
    }

    return {
        listByUser: listByUser,
        generate: generate
    };
})();
