/* ==========================================================================
   Learnova Quiz API (window.LearnovaQuizApi)
   Quiz questions per lesson. Product rule: instructors bank
   QUIZ_DEFAULTS.BANK_SIZE (20) MCQs per lesson and each student receives
   QUIZ_DEFAULTS.RANDOM_PER_STUDENT (5) random questions at attempt time.
   Every call unwraps the ApiResponse envelope ({success, message, data,
   timestamp}) so pages receive the payload directly (like the offline mock).
   ========================================================================== */

window.LearnovaQuizApi = (function () {
    'use strict';

    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function queryString(params) {
        var parts = [];
        Object.keys(params || {}).forEach(function (key) {
            var value = params[key];
            if (value === null || value === undefined || value === '') return;
            parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
        });
        return parts.length ? '?' + parts.join('&') : '';
    }

    /* Instructor: the full question bank for a lesson (with correct answers).
       `course` disambiguates same-titled lessons across courses. */
    function list(lessonId, course) {
        return unwrap(LearnovaApiClient.get(
            '/quizzes/lesson/' + encodeURIComponent(lessonId) + queryString({ course: course })
        ));
    }

    function get(id) {
        return unwrap(LearnovaApiClient.get('/quizzes/' + encodeURIComponent(id)));
    }

    function create(lessonId, question, course) {
        return unwrap(LearnovaApiClient.post(
            '/quizzes/lesson/' + encodeURIComponent(lessonId) + queryString({ course: course }),
            question
        ));
    }

    function update(id, question) {
        return unwrap(LearnovaApiClient.put('/quizzes/' + encodeURIComponent(id), question));
    }

    function remove(id) {
        return unwrap(LearnovaApiClient.del('/quizzes/' + encodeURIComponent(id)));
    }

    /* Student-facing: server draws RANDOM_PER_STUDENT questions at random
       from the lesson's full BANK_SIZE question bank. */
    function randomize(lessonId, count, course) {
        var n = count || LearnovaConstants.QUIZ_DEFAULTS.RANDOM_PER_STUDENT;
        return unwrap(LearnovaApiClient.get(
            '/quizzes/lesson/' + encodeURIComponent(lessonId) +
            '/random' + queryString({ count: n, course: course })
        ));
    }

    /* Pass state + remaining daily attempts (bypass=1 for bypass exams). */
    function status(lessonId, bypass, course) {
        return unwrap(LearnovaApiClient.get(
            '/quizzes/lesson/' + encodeURIComponent(lessonId) +
            '/status' + queryString({ bypass: bypass ? 1 : undefined, course: course })
        ));
    }

    return {
        list: list,
        get: get,
        create: create,
        update: update,
        remove: remove,
        randomize: randomize,
        status: status
    };
})();
