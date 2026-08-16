/* ==========================================================================
   Learnova Public Course API
   --------------------------------------------------------------------------
   Canonical public course REST contract:

       GET /api/v1/categories
       GET /api/v1/courses
       GET /api/v1/courses/{courseId}
       GET /api/v1/courses/{courseId}/syllabus
       GET /api/v1/lessons/{lessonId}/content

   Instructor/admin course mutations belong to their own API modules.

   The old /api/v1/catalogue/* backend has been retired.
   ========================================================================== */

window.LearnovaCourseApi = (function () {
    'use strict';

    var MAX_LIST_SIZE = 50;

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

    function publishedStatus() {
        if (
            window.LearnovaConstants &&
            LearnovaConstants.COURSE_STATUS &&
            LearnovaConstants.COURSE_STATUS.PUBLISHED
        ) {
            return LearnovaConstants.COURSE_STATUS.PUBLISHED;
        }

        return 'published';
    }

    function normalizeCourse(card) {
        if (!card || typeof card !== 'object') {
            return card;
        }

        var course = Object.assign({}, card);

        course.id =
            card.courseId !== undefined &&
            card.courseId !== null
                ? card.courseId
                : card.id;

        course.courseId = course.id;

        course.slug = card.slug || '';

        course.title = card.title || '';

        course.description =
            card.shortDescription !== undefined &&
            card.shortDescription !== null
                ? card.shortDescription
                : (
                    card.description !== undefined &&
                    card.description !== null
                        ? card.description
                        : ''
                );

        course.shortDescription =
            card.shortDescription !== undefined
                ? card.shortDescription
                : course.description;

        course.category =
            card.categoryName !== undefined
                ? card.categoryName
                : card.category;

        course.categoryName =
            card.categoryName !== undefined
                ? card.categoryName
                : card.category;

        /*
         * Category and Track are different business concepts.
         * Do not fabricate Track membership from category data.
         */
        course.tracks =
            Array.isArray(card.tracks)
                ? card.tracks.slice()
                : [];

        if (card.cardStatus !== undefined) {
            course.status = publishedStatus();
        }

        course.cardStatus = card.cardStatus;

        course.rating =
            card.avgRating !== undefined
                ? card.avgRating
                : card.rating;

        course.avgRating =
            card.avgRating !== undefined
                ? card.avgRating
                : card.rating;

        course.reviewCount =
            Number(card.reviewCount) || 0;

        course.totalLessons =
            Number(card.totalLessons) || 0;

        course.estimatedDurationMinutes =
            Number(card.estimatedDurationMinutes) || 0;

        course.instructorName =
            card.instructorName || '';

        course.locked =
            Boolean(card.locked);

        course.enrolled =
            Boolean(card.enrolled);

        course.completed =
            Boolean(card.completed);

        course.lockReason =
            card.lockReason || null;

        return course;
    }

    function normalizePage(result) {
        var value = unwrap(result);

        if (Array.isArray(value)) {
            return {
                content: value.map(normalizeCourse),
                page: 0,
                size: value.length,
                totalElements: value.length,
                totalPages: value.length ? 1 : 0,
                first: true,
                last: true
            };
        }

        if (!value || typeof value !== 'object') {
            return {
                content: [],
                page: 0,
                size: 0,
                totalElements: 0,
                totalPages: 0,
                first: true,
                last: true
            };
        }

        return {
            content: Array.isArray(value.content)
                ? value.content.map(normalizeCourse)
                : [],

            page:
                Number.isInteger(value.page)
                    ? value.page
                    : Number(value.page) || 0,

            size:
                Number.isInteger(value.size)
                    ? value.size
                    : Number(value.size) || 0,

            totalElements:
                Number(value.totalElements) || 0,

            totalPages:
                Number(value.totalPages) || 0,

            first:
                value.first !== false,

            last:
                value.last !== false
        };
    }

    function buildSearchQuery(options) {
        var params = options || {};
        var query = new URLSearchParams();

        if (
            params.search !== null &&
            params.search !== undefined &&
            String(params.search).trim()
        ) {
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
            params.difficulty !== null &&
            params.difficulty !== undefined &&
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
                ? String(params.page)
                : '0'
        );

        query.set(
            'size',
            Number.isInteger(params.size)
                ? String(params.size)
                : '12'
        );

        return query.toString();
    }

    function searchCourses(options) {
        return LearnovaApiClient
            .get(
                '/courses?' +
                buildSearchQuery(options)
            )
            .then(normalizePage);
    }

    /*
     * Transitional convenience method for screens that need a flat list.
     *
     * This deliberately uses the maximum backend page size rather than the
     * catalogue default of 12.
     *
     * Pages that need true pagination should call searchCourses().
     */
    function list() {
        return searchCourses({
            sort: 'title',
            page: 0,
            size: MAX_LIST_SIZE
        }).then(function (page) {
            return page.content;
        });
    }

    function get(courseId) {
        return LearnovaApiClient
            .get(
                '/courses/' +
                encodeURIComponent(courseId)
            )
            .then(unwrap);
    }

    function getCategories() {
        return LearnovaApiClient
            .get('/categories')
            .then(unwrap)
            .then(function (categories) {
                return Array.isArray(categories)
                    ? categories
                    : [];
            });
    }

    function getSyllabus(courseId) {
        return LearnovaApiClient
            .get(
                '/courses/' +
                encodeURIComponent(courseId) +
                '/syllabus'
            )
            .then(unwrap);
    }

    function getLessonContent(lessonId) {
        return LearnovaApiClient
            .get(
                '/lessons/' +
                encodeURIComponent(lessonId) +
                '/content'
            )
            .then(unwrap);
    }

    /*
     * Temporary frontend compatibility aliases.
     *
     * They use the canonical endpoints above; there is no longer a
     * /catalogue backend.
     *
     * These aliases will disappear when the Student/Instructor frontend
     * callers are rewritten in the next frontend cleanup phase.
     */
    function getCatalogueCategories() {
        return getCategories();
    }

    function searchCatalogue(options) {
        return searchCourses(options);
    }

    return {
        list: list,
        get: get,

        searchCourses: searchCourses,
        getCategories: getCategories,

        getSyllabus: getSyllabus,
        getLessonContent: getLessonContent,

        getCatalogueCategories: getCatalogueCategories,
        searchCatalogue: searchCatalogue,

        normalizeCourse: normalizeCourse
    };
})();