/* ==========================================================================
   Learnova Progress API (window.LearnovaProgressApi)
   Every call unwraps the ApiResponse envelope ({success, message, data,
   timestamp}) so pages receive the payload directly (like the offline mock).
   ========================================================================== */

window.LearnovaProgressApi = (function () {
    'use strict';

    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function getByUser() {
        return unwrap(LearnovaApiClient.get('/progress/mine'));
    }

    function updateLesson(courseId, lessonId, payload) {
        return unwrap(LearnovaApiClient.put(
            '/progress/' + encodeURIComponent(courseId) + '/lessons/' + encodeURIComponent(lessonId),
            payload
        ));
    }

    function markQuizAttempt(courseId, lessonId, payload) {
        return unwrap(LearnovaApiClient.post(
            '/progress/' + encodeURIComponent(courseId) + '/lessons/' + encodeURIComponent(lessonId) + '/quiz',
            payload
        ));
    }

    return {
        getByUser: getByUser,
        updateLesson: updateLesson,
        markQuizAttempt: markQuizAttempt
    };
})();
