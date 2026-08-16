/* ==========================================================================
   Learnova Prerequisite API
   --------------------------------------------------------------------------
   Canonical Instructor/Admin contract:

       GET
       /api/v1/instructor/courses/{courseId}/prerequisites

       PUT
       /api/v1/instructor/courses/{courseId}/prerequisites

   The PUT replaces the COMPLETE prerequisite set atomically.

   PostgreSQL owns:
       - ownership
       - course lifecycle
       - candidate validity
       - duplicate detection
       - minimum-score validation
       - cycle prevention
       - maximum chain depth
   ========================================================================== */

window.LearnovaPrerequisiteApi = (function () {
    'use strict';


    function unwrap(response) {
        if (
            response &&
            typeof response === 'object' &&
            Object.prototype.hasOwnProperty.call(
                response,
                'data'
            )
        ) {
            return response.data;
        }

        return response;
    }


    function coursePath(courseId) {
        return (
            '/instructor/courses/' +
            encodeURIComponent(courseId) +
            '/prerequisites'
        );
    }


    function getEditor(courseId) {
        return LearnovaApiClient
            .get(
                coursePath(courseId)
            )
            .then(unwrap);
    }


    function replace(
        courseId,
        prerequisites
    ) {
        return LearnovaApiClient
            .put(
                coursePath(courseId),
                {
                    prerequisites:
                        Array.isArray(prerequisites)
                            ? prerequisites
                            : []
                }
            )
            .then(unwrap);
    }


    return {
        getEditor: getEditor,
        replace: replace
    };

})();