/* ==========================================================================
   Learnova Route Guard (window.LearnovaRouteGuard)
   Protects pages by role and routes users to their role dashboard.
   Supports multi-role users (spec 1.2): a user who holds several roles is
   sent to their highest-priority dashboard (Admin > Instructor > Student).
   ========================================================================== */

window.LearnovaRouteGuard = (function () {
    'use strict';

    var LOGIN_URL = '/frontend/pages/auth/login.html';

    var DASHBOARDS = {};
    DASHBOARDS[LearnovaConstants.ROLES.STUDENT] = '/frontend/pages/student/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.INSTRUCTOR] = '/frontend/pages/instructor/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.ADMIN] = '/frontend/pages/admin/dashboard.html';

    function protectPage(allowedRoles) {
        var roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

        if (!LearnovaSession.isAuthenticated() ||
            LearnovaSession.isBlocked() ||
            !LearnovaSession.requireRole(roles)) {
            var redirect = window.location.pathname + window.location.search;
            window.location.href = LOGIN_URL + '?redirect=' + encodeURIComponent(redirect);
            return false;
        }
        return true;
    }

    function redirectToDashboard() {
        var destination = DASHBOARDS[LearnovaSession.primaryRole()] || LOGIN_URL;
        window.location.href = destination;
    }

    return {
        protectPage: protectPage,
        redirectToDashboard: redirectToDashboard
    };
})();
