/* ==========================================================================
   Learnova Course API (window.LearnovaCourseApi)
   ========================================================================== */

window.LearnovaCourseApi = (function () {
    'use strict';

    function list() {
        return LearnovaApiClient.get('/courses');
    }

    function get(id) {
        return LearnovaApiClient.get('/courses/' + id);
    }

    function create(payload) {
        return LearnovaApiClient.post('/courses', payload);
    }

    function update(id, payload) {
        return LearnovaApiClient.put('/courses/' + id, payload);
    }

    function remove(id) {
        return LearnovaApiClient.del('/courses/' + id);
    }

    function getCurriculum(courseId) {
        return LearnovaApiClient.get('/courses/' + courseId + '/curriculum');
    }

    function setCurriculum(courseId, curriculum) {
        return LearnovaApiClient.put('/courses/' + courseId + '/curriculum', curriculum);
    }

    function getLesson(courseId, lessonId) {
        return LearnovaApiClient.get('/courses/' + courseId + '/lessons/' + encodeURIComponent(lessonId));
    }

    function setLesson(courseId, lessonId, content) {
        return LearnovaApiClient.put('/courses/' + courseId + '/lessons/' + encodeURIComponent(lessonId), content);
    }

    return {
        list: list,
        get: get,
        create: create,
        update: update,
        remove: remove,
        getCurriculum: getCurriculum,
        setCurriculum: setCurriculum,
        getLesson: getLesson,
        setLesson: setLesson
    };
})();
