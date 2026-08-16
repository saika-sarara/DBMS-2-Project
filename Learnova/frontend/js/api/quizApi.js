/* ==========================================================================
   Learnova Quiz API
   ========================================================================== */

window.LearnovaQuizApi = (function () {
    'use strict';

    function unwrap(promise) {
        return promise.then(
            function (envelope) {
                if (
                    envelope &&
                    typeof envelope === 'object' &&
                    Object.prototype.hasOwnProperty.call(
                        envelope,
                        'data'
                    )
                ) {
                    return envelope.data;
                }

                return envelope;
            }
        );
    }

    function queryString(params) {
        var search = new URLSearchParams();

        Object.keys(params || {})
            .forEach(function (key) {
                var value = params[key];

                if (
                    value === undefined ||
                    value === null ||
                    value === ''
                ) {
                    return;
                }

                search.set(
                    key,
                    String(value)
                );
            });

        var query = search.toString();

        return query
            ? '?' + query
            : '';
    }


    /* ======================================================
       Instructor question bank
       ====================================================== */

    function list(
        lesson,
        course
    ) {
        return unwrap(
            LearnovaApiClient.get(
                '/instructor/quizzes/lesson/' +
                encodeURIComponent(lesson) +
                queryString({
                    course: course
                })
            )
        );
    }


    function create(
        lesson,
        question,
        course
    ) {
        return unwrap(
            LearnovaApiClient.post(
                '/instructor/quizzes/lesson/' +
                encodeURIComponent(lesson) +
                queryString({
                    course: course
                }),
                question
            )
        );
    }


    function update(
        questionId,
        question
    ) {
        return unwrap(
            LearnovaApiClient.put(
                '/instructor/quizzes/questions/' +
                encodeURIComponent(questionId),
                question
            )
        );
    }


    function remove(
        questionId
    ) {
        return unwrap(
            LearnovaApiClient.del(
                '/instructor/quizzes/questions/' +
                encodeURIComponent(questionId)
            )
        );
    }


    /* ======================================================
       Student quiz
       ====================================================== */

    function randomize(
        lesson,
        count,
        course,
        bypass
    ) {
        var amount =
            count ||
            LearnovaConstants
                .QUIZ_DEFAULTS
                .RANDOM_PER_STUDENT;

        return unwrap(
            LearnovaApiClient.get(
                '/student/quizzes/lesson/' +
                encodeURIComponent(lesson) +
                '/random' +
                queryString({
                    count: amount,
                    course: course,
                    bypass: bypass ? true : undefined
                })
            )
        );
    }


    /*
     * Keep the current function signature:
     *
     * status(lesson, bypass, course)
     *
     * because quizAttempt.js currently calls it this way.
     */
    function status(
        lesson,
        bypass,
        course
    ) {
        return unwrap(
            LearnovaApiClient.get(
                '/student/quizzes/lesson/' +
                encodeURIComponent(lesson) +
                '/status' +
                queryString({
                    bypass: bypass ? true : undefined,
                    course: course
                })
            )
        );
    }


    return {
        list: list,
        create: create,
        update: update,
        remove: remove,
        randomize: randomize,
        status: status
    };
})();