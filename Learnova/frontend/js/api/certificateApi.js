/* ==========================================================================
   Learnova Certificate API (window.LearnovaCertificateApi)
   ========================================================================== */

window.LearnovaCertificateApi = (function () {
    'use strict';

    function listByUser() {
        return LearnovaApiClient.get('/certificates/mine');
    }

    function generate(courseId) {
        return LearnovaApiClient.post('/certificates', {
            entityId: courseId,
            type: 'course'
        });
    }

    function verify(code) {
        return LearnovaApiClient.get(
            '/certificates/verify/' + encodeURIComponent(code)
        );
    }

    return {
        listByUser: listByUser,
        generate: generate,
        verify: verify
    };
})();
