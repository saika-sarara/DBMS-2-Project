/* ==========================================================================
   Learnova Enrollment API (window.LearnovaEnrollmentApi)
   ========================================================================== */

window.LearnovaEnrollmentApi = (function () {
    'use strict';

    function enroll(courseId) {
        return LearnovaApiClient.post('/enrollments', { courseId: courseId });
    }

    function listByUser() {
        return LearnovaApiClient.get('/enrollments/mine');
    }

    function unenroll(courseId) {
        return LearnovaApiClient.del('/enrollments/course/' + courseId);
    }

    return {
        enroll: enroll,
        listByUser: listByUser,
        unenroll: unenroll
    };
})();
