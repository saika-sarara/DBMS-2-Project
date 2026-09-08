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

    /* The only backend progress route is the quiz-submission endpoint
       (POST /progress/{course}/lessons/{lesson}/quiz). */
    function markQuizAttempt(courseId, lessonId, payload) {
        return unwrap(LearnovaApiClient.post(
            '/progress/' + encodeURIComponent(courseId) + '/lessons/' + encodeURIComponent(lessonId) + '/quiz',
            payload
        ));
    }

    return {
        markQuizAttempt: markQuizAttempt
    };
})();