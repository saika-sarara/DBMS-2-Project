/* ==========================================================================
   Learnova Instructor API (window.LearnovaInstructorApi)
   Student-facing instructor role requests (spec 1.3). Admins moderate these
   through LearnovaAdminApi.
   ========================================================================== */

window.LearnovaInstructorApi = (function () {
    'use strict';

    function myRequest() {
        return LearnovaApiClient.get('/instructor-requests/mine');
    }

    function createRequest(note) {
        return LearnovaApiClient.post('/instructor-requests', { note: note || '' });
    }

    return {
        myRequest: myRequest,
        createRequest: createRequest
    };
})();
