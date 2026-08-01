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

    return {
        list: list,
        get: get,
        create: create,
        update: update,
        remove: remove
    };
})();
