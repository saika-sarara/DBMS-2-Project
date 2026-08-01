/* ==========================================================================
   Learnova Quiz API (window.LearnovaQuizApi)
   Quiz questions per lesson. Product rule: instructors bank
   QUIZ_DEFAULTS.BANK_SIZE (20) MCQs per lesson and each student receives
   QUIZ_DEFAULTS.RANDOM_PER_STUDENT (5) random questions at attempt time.
   ========================================================================== */

window.LearnovaQuizApi = (function () {
    'use strict';

    function list(lessonId) {
        return LearnovaApiClient.get('/quizzes/lesson/' + lessonId);
    }

    function get(id) {
        return LearnovaApiClient.get('/quizzes/' + id);
    }

    function create(lessonId, question) {
        return LearnovaApiClient.post('/quizzes/lesson/' + lessonId, question);
    }

    function update(id, question) {
        return LearnovaApiClient.put('/quizzes/' + id, question);
    }

    function remove(id) {
        return LearnovaApiClient.del('/quizzes/' + id);
    }

    /* Student-facing: server draws RANDOM_PER_STUDENT questions at random
       from the lesson's full BANK_SIZE question bank. */
    function randomize(lessonId, count) {
        var n = count || LearnovaConstants.QUIZ_DEFAULTS.RANDOM_PER_STUDENT;
        return LearnovaApiClient.get('/quizzes/lesson/' + lessonId + '/random?count=' + n);
    }

    return {
        list: list,
        get: get,
        create: create,
        update: update,
        remove: remove,
        randomize: randomize
    };
})();
