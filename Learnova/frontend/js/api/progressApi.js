/* ==========================================================================
   Learnova Progress API (window.LearnovaProgressApi)
   ========================================================================== */

window.LearnovaProgressApi = (function () {
    'use strict';

    function getByUser() {
        return LearnovaApiClient.get('/progress/mine');
    }

    function updateLesson(courseId, lessonId, payload) {
        return LearnovaApiClient.put('/progress/' + encodeURIComponent(courseId) + '/lessons/' + encodeURIComponent(lessonId), payload);
    }

    function markQuizAttempt(courseId, lessonId, payload) {
        return LearnovaApiClient.post('/progress/' + encodeURIComponent(courseId) + '/lessons/' + encodeURIComponent(lessonId) + '/quiz', payload);
    }

    return {
        getByUser: getByUser,
        updateLesson: updateLesson,
        markQuizAttempt: markQuizAttempt
    };
})();
