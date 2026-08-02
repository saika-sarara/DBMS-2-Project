/* ==========================================================================
   Learnova Review API (window.LearnovaReviewApi)
   ========================================================================== */

window.LearnovaReviewApi = (function () {
    'use strict';

    function listByCourse(courseId) {
        return LearnovaApiClient.get('/courses/' + courseId + '/reviews');
    }

    function create(courseId, review) {
        return LearnovaApiClient.post('/courses/' + courseId + '/reviews', review);
    }

    return {
        listByCourse: listByCourse,
        create: create
    };
})();
