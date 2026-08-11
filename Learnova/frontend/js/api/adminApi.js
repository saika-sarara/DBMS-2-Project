/* ==========================================================================
   Learnova Admin API (window.LearnovaAdminApi)
   User management (spec 6.x), instructor request moderation (spec 1.3),
   and course lifecycle moderation (spec 2.2). Account status uses
   active / suspended / banned.
   ========================================================================== */

window.LearnovaAdminApi = (function () {
    'use strict';

    /* Course moderation and category endpoints are served by
       AdminCourseController, which wraps every response in ApiResponse,
       so those calls unwrap `data` for the caller. User management and
       instructor-request endpoints (AdminController) return raw JSON and
       are left untouched. */
    function unwrap(promise) {
        return promise.then(function (body) {
            if (body && typeof body === 'object' && 'data' in body) {
                return body.data;
            }
            return body;
        });
    }

    function listUsers() {
        return LearnovaApiClient.get('/admin/users');
    }

    function createUser(payload) {
        return LearnovaApiClient.post('/admin/users', payload);
    }

    function updateUserRole(userId, role) {
        return LearnovaApiClient.put('/admin/users/' + userId + '/role', { role: role });
    }

    /* status: 'active' | 'suspended' | 'banned' (spec 1.1) */
    function setUserStatus(userId, status) {
        return LearnovaApiClient.put('/admin/users/' + userId + '/status', { status: status });
    }

    function deleteUser(userId) {
        return LearnovaApiClient.del('/admin/users/' + userId);
    }

    function listRoles() {
        return LearnovaApiClient.get('/admin/roles');
    }

    /* Aggregate platform stats for the admin dashboard. */
    function stats() {
        return LearnovaApiClient.get('/admin/stats');
    }

    /* ---- Instructor requests (spec 1.3) ---- */
    function listInstructorRequests() {
        return LearnovaApiClient.get('/admin/instructor-requests');
    }

    /* Approve adds the Instructor role to the requester's account. */
    function approveInstructorRequest(requestId) {
        return LearnovaApiClient.post('/admin/instructor-requests/' + requestId + '/approve', {});
    }

    function rejectInstructorRequest(requestId) {
        return LearnovaApiClient.post('/admin/instructor-requests/' + requestId + '/reject', {});
    }

    /* ---- Course moderation (spec 2.2) ---- */
    function listCourses() {
        return unwrap(LearnovaApiClient.get('/admin/courses'));
    }

    /* Publish moves a course from pending -> published. */
    function publishCourse(courseId) {
        return unwrap(LearnovaApiClient.post(
            '/admin/courses/' + courseId + '/publish',
            {}
        ));
    }

    /* Reject moves a course from pending -> rejected. A reason is required. */
    function rejectCourse(courseId, reason) {
        return unwrap(LearnovaApiClient.post(
            '/admin/courses/' + courseId + '/reject',
            { reason: reason || '' }
        ));
    }

    /* Archive takes a published course offline. */
    function archiveCourse(courseId) {
        return unwrap(LearnovaApiClient.post(
            '/admin/courses/' + courseId + '/archive',
            {}
        ));
    }

    /* ---- Category management ---- */
    function listCategories() {
        return unwrap(LearnovaApiClient.get('/admin/categories'));
    }

    function createCategory(payload) {
        return unwrap(LearnovaApiClient.post('/admin/categories', payload));
    }

    function updateCategory(categoryId, payload) {
        return unwrap(LearnovaApiClient.put(
            '/admin/categories/' + categoryId,
            payload
        ));
    }

    function deleteCategory(categoryId) {
        return unwrap(LearnovaApiClient.del('/admin/categories/' + categoryId));
    }

    return {
        listUsers: listUsers,
        createUser: createUser,
        updateUserRole: updateUserRole,
        setUserStatus: setUserStatus,
        deleteUser: deleteUser,
        listRoles: listRoles,
        stats: stats,
        listInstructorRequests: listInstructorRequests,
        approveInstructorRequest: approveInstructorRequest,
        rejectInstructorRequest: rejectInstructorRequest,
        listCourses: listCourses,
        publishCourse: publishCourse,
        rejectCourse: rejectCourse,
        archiveCourse: archiveCourse,
        listCategories: listCategories,
        createCategory: createCategory,
        updateCategory: updateCategory,
        deleteCategory: deleteCategory
    };
})();
