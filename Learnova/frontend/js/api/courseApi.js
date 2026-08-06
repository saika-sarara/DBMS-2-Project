/* ==========================================================================
   Learnova Course API (window.LearnovaCourseApi)
   ========================================================================== */

window.LearnovaCourseApi = (function () {
    'use strict';

    /* The live backend returns the catalogue as a paged envelope of
       PersonalizedCourseCardResponse cards ({content: [...], page, ...})
       while the offline mock returns a plain array of courses. Frontend
       pages (student dashboard, catalog, prerequisite editor, admin
       dashboard) consume both as a plain array of course-like objects with
       mock-style fields (id, slug, title, description, track, status).
       This mapper bridges the two shapes so pages never have to branch. */
    function toFrontendCourse(card) {
        if (!card || typeof card !== 'object') return card;
        var out = Object.assign({}, card);
        out.id = card.courseId !== undefined && card.courseId !== null
            ? card.courseId
            : card.id;
        out.slug = card.slug;
        out.title = card.title;
        out.description = card.shortDescription !== undefined
            ? card.shortDescription
            : card.description;
        out.track = card.categoryName || card.track;
        /* The backend catalogue only ever returns published courses, so a
           card carrying cardStatus maps to the lifecycle status the pages
           filter on ('published'). Mock courses already store `status`. */
        out.status = card.cardStatus !== undefined
            ? LearnovaConstants.COURSE_STATUS.PUBLISHED
            : card.status;
        out.cardStatus = card.cardStatus;
        out.rating = card.avgRating !== undefined ? card.avgRating : card.rating;
        out.reviewCount = card.reviewCount;
        out.difficulty = card.difficulty;
        out.totalLessons = card.totalLessons;
        out.instructorName = card.instructorName;
        out.enrolled = !!card.enrolled;
        out.completed = !!card.completed;
        return out;
    }

    function toFrontendList(result) {
        if (Array.isArray(result)) return result.map(toFrontendCourse);
        if (result && Array.isArray(result.content)) {
            return Object.assign({}, result, {
                content: result.content.map(toFrontendCourse)
            });
        }
        return result;
    }

    function list() {
        return LearnovaApiClient.get('/courses').then(function (result) {
            if (Array.isArray(result)) return result.map(toFrontendCourse);
            if (result && Array.isArray(result.content)) {
                return result.content.map(toFrontendCourse);
            }
            return [];
        });
    }

    function get(id) {
        return LearnovaApiClient.get('/courses/' + encodeURIComponent(id));
    }

    /* Personalized catalogue search (backend fn_search_course_catalogue).
       Same parameters as searchCatalogue but against the /courses endpoint
       so a signed-in student gets personalized results. */
    function searchCourses(options) {
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
            '/courses?' + query.toString()
        ).then(toFrontendList);
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

    function getSyllabus(courseId) {
        return LearnovaApiClient.get(
            '/courses/' +
            encodeURIComponent(courseId) +
            '/syllabus'
        );
    }

    function getLessonContent(lessonId) {
        return LearnovaApiClient.get(
            '/lessons/' +
            encodeURIComponent(lessonId) +
            '/content'
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
        ).then(toFrontendList);
    }

    return {
        list: list,
        get: get,
        searchCourses: searchCourses,
        create: create,
        update: update,
        remove: remove,
        getCurriculum: getCurriculum,
        getSyllabus: getSyllabus,
        getLessonContent: getLessonContent,
        setCurriculum: setCurriculum,
        getLesson: getLesson,
        setLesson: setLesson,
        getCatalogueCategories: getCatalogueCategories,
        searchCatalogue: searchCatalogue
    };
})();