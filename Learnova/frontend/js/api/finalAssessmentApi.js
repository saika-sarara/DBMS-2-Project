/* ==========================================================================
   Learnova Final Assessment API (student)
   Thin wrapper over the real final-assessment endpoints:
       GET  /student/courses/{courseId}/final-assessment/status
       POST /student/courses/{courseId}/final-assessment/attempts
       PUT  /student/final-assessment/attempts/{attemptId}/answers/{questionId}
       POST /student/final-assessment/attempts/{attemptId}/submit
       GET  /student/courses/{courseId}/final-assessment/history
   ========================================================================== */

window.LearnovaFinalAssessmentApi = (function () {
    'use strict';

    function unwrap(value) {
        if (
            value &&
            typeof value === 'object' &&
            Object.prototype.hasOwnProperty.call(value, 'data')
        ) {
            return value.data;
        }

        return value;
    }

    function status(courseId) {
        return LearnovaApiClient
            .get(
                '/student/courses/' +
                encodeURIComponent(courseId) +
                '/final-assessment/status'
            )
            .then(unwrap);
    }

    function startAttempt(courseId) {
        return LearnovaApiClient
            .post(
                '/student/courses/' +
                encodeURIComponent(courseId) +
                '/final-assessment/attempts'
            )
            .then(unwrap);
    }

    function saveAnswer(attemptId, questionId, selectedOptionId) {
        return LearnovaApiClient
            .put(
                '/student/final-assessment/attempts/' +
                encodeURIComponent(attemptId) +
                '/answers/' +
                encodeURIComponent(questionId),
                {
                    selectedOptionId: selectedOptionId
                }
            )
            .then(unwrap);
    }

    function submit(attemptId) {
        return LearnovaApiClient
            .post(
                '/student/final-assessment/attempts/' +
                encodeURIComponent(attemptId) +
                '/submit'
            )
            .then(unwrap);
    }

    function history(courseId) {
        return LearnovaApiClient
            .get(
                '/student/courses/' +
                encodeURIComponent(courseId) +
                '/final-assessment/history'
            )
            .then(unwrap);
    }

    return {
        status: status,
        startAttempt: startAttempt,
        saveAnswer: saveAnswer,
        submit: submit,
        history: history
    };
})();