/* ==========================================================================
   Learnova Prerequisite API (window.LearnovaPrerequisiteApi)
   ========================================================================== */

window.LearnovaPrerequisiteApi = (function () {
    'use strict';

    function listForCourse(courseId) {
        return LearnovaApiClient.get('/courses/' + courseId + '/prerequisites');
    }

    function setPrerequisites(courseId, prerequisiteIds) {
        return LearnovaApiClient.put('/courses/' + courseId + '/prerequisites', {
            prerequisiteIds: prerequisiteIds
        });
    }

    return {
        listForCourse: listForCourse,
        setPrerequisites: setPrerequisites
    };
})();
