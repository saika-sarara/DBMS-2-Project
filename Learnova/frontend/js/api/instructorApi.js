/* ==========================================================================
   Learnova Instructor API (window.LearnovaInstructorApi)
   Student-facing instructor role requests (spec 1.3). Admins moderate these
   through LearnovaAdminApi.
   ========================================================================== */

window.LearnovaInstructorApi = (function () {
    'use strict';

    /* The Spring Boot backend wraps instructor endpoints in ApiResponse,
       so every call unwraps `data` for the caller. */
    function unwrap(promise) {
        return promise.then(function (body) {
            if (body && typeof body === 'object' && 'data' in body) {
                return body.data;
            }
            return body;
        });
    }

    function myRequest() {
        return unwrap(LearnovaApiClient.get('/instructor-requests/mine'));
    }

    function createRequest(note) {
        return unwrap(LearnovaApiClient.post('/instructor-requests', { note: note || '' }));
    }

    /* ---- Instructor course authoring (spec 2.2) ---- */

    function listCourses() {
        return unwrap(LearnovaApiClient.get('/instructor/courses'));
    }

    function getCourse(courseId) {
        return unwrap(LearnovaApiClient.get(
            '/instructor/courses/' + encodeURIComponent(courseId)
        ));
    }

    function getCurriculum(courseId) {
        return unwrap(LearnovaApiClient.get(
            '/instructor/courses/' +
            encodeURIComponent(courseId) +
            '/curriculum'
        ));
    }

    /* The backend replaces the whole curriculum in one transaction
       (sp_replace_course_curriculum). */
    function setCurriculum(courseId, curriculum) {
        return unwrap(LearnovaApiClient.put(
            '/instructor/courses/' +
            encodeURIComponent(courseId) +
            '/curriculum',
            curriculum
        ));
    }

    function createCourse(payload) {
        return unwrap(LearnovaApiClient.post('/instructor/courses', payload));
    }

    function updateCourse(courseId, payload) {
        return unwrap(LearnovaApiClient.put(
            '/instructor/courses/' + encodeURIComponent(courseId),
            payload
        ));
    }

    function submitCourse(courseId) {
        return unwrap(LearnovaApiClient.post(
            '/instructor/courses/' +
            encodeURIComponent(courseId) +
            '/submit'
        ));
    }

    function deleteCourse(courseId) {
        return unwrap(LearnovaApiClient.del(
            '/instructor/courses/' + encodeURIComponent(courseId)
        ));
    }

    return {
        myRequest: myRequest,
        createRequest: createRequest,
        listCourses: listCourses,
        getCourse: getCourse,
        getCurriculum: getCurriculum,
        setCurriculum: setCurriculum,
        createCourse: createCourse,
        updateCourse: updateCourse,
        submitCourse: submitCourse,
        deleteCourse: deleteCourse
    };
})();
