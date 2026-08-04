/* ==========================================================================
   Learnova Course API (window.LearnovaCourseApi)
   ========================================================================== */

window.LearnovaCourseApi = (function () {
    'use strict';

    function list() {
        return LearnovaApiClient.get('/courses');
    }

    function get(id) {
        return LearnovaApiClient.get('/courses/' + encodeURIComponent(id));
    }

    function create(payload) {
        return LearnovaApiClient.post('/courses', payload);
    }

    function update(id, payload) {
        return LearnovaApiClient.put(
            '/courses/' + encodeURIComponent(id),
            payload
        );
    }

    function remove(id) {
        return LearnovaApiClient.del(
            '/courses/' + encodeURIComponent(id)
        );
    }

    function getCurriculum(courseId) {
        return LearnovaApiClient.get(
            '/courses/' +
            encodeURIComponent(courseId) +
            '/curriculum'
        );
    }

    function setCurriculum(courseId, curriculum) {
        return LearnovaApiClient.put(
            '/courses/' +
            encodeURIComponent(courseId) +
            '/curriculum',
            curriculum
        );
    }

    function getLesson(courseId, lessonId) {
        return LearnovaApiClient.get(
            '/courses/' +
            encodeURIComponent(courseId) +
            '/lessons/' +
            encodeURIComponent(lessonId)
        );
    }

    function setLesson(courseId, lessonId, content) {
        return LearnovaApiClient.put(
            '/courses/' +
            encodeURIComponent(courseId) +
            '/lessons/' +
            encodeURIComponent(lessonId),
            content
        );
    }

    function getCatalogueCategories() {
        return LearnovaApiClient.get(
            '/catalogue/categories'
        );
    }

    function searchCatalogue(options) {
        var params = options || {};
        var query = new URLSearchParams();

        if (params.search && String(params.search).trim()) {
            query.set(
                'search',
                String(params.search).trim()
            );
        }

        if (
            params.categoryId !== null &&
            params.categoryId !== undefined &&
            String(params.categoryId).trim() !== ''
        ) {
            query.set(
                'categoryId',
                String(params.categoryId)
            );
        }

        if (
            params.difficulty &&
            String(params.difficulty).trim()
        ) {
            query.set(
                'difficulty',
                String(params.difficulty)
                    .trim()
                    .toLowerCase()
            );
        }

        query.set(
            'sort',
            params.sort || 'relevance'
        );

        query.set(
            'page',
            Number.isInteger(params.page)
                ? params.page
                : 0
        );

        query.set(
            'size',
            Number.isInteger(params.size)
                ? params.size
                : 12
        );

        return LearnovaApiClient.get(
            '/catalogue/courses?' + query.toString()
        );
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
        setLesson: setLesson,
        getCatalogueCategories: getCatalogueCategories,
        searchCatalogue: searchCatalogue
    };
})();