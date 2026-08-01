/* ==========================================================================
   Learnova Progress API (window.LearnovaProgressApi)
   ========================================================================== */

window.LearnovaProgressApi = (function () {
    'use strict';

    function getByUser() {
        return LearnovaApiClient.get('/progress/mine');
    }

    function updateLesson(courseId, lessonId, payload) {
        return LearnovaApiClient.put('/progress/' + courseId + '/lessons/' + lessonId, payload);
    }

    function markQuizAttempt(courseId, lessonId, payload) {
        return LearnovaApiClient.post('/progress/' + courseId + '/lessons/' + lessonId + '/quiz', payload);
    }

    return {
        getByUser: getByUser,
        updateLesson: updateLesson,
        markQuizAttempt: markQuizAttempt
    };
})();
