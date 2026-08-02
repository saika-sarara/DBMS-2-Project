/* ==========================================================================
   Learnova Route Guard (window.LearnovaRouteGuard)
   Protects pages by role and routes users to their role dashboard.
   Supports multi-role users (spec 1.2): a user who holds several roles is
   sent to their highest-priority dashboard (Admin > Instructor > Student).
   ========================================================================== */

window.LearnovaRouteGuard = (function () {
    'use strict';

    /* Dashboard pages live under <base>/pages/<role>/dashboard.html. The base
       is derived from the current page location, so redirects keep working no
       matter how the frontend is served (repo root, the frontend folder, Live
       Server, or file://) instead of hard-coding /frontend/... paths. */
    var DASHBOARDS = {};
    DASHBOARDS[LearnovaConstants.ROLES.STUDENT] = 'student/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.INSTRUCTOR] = 'instructor/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.ADMIN] = 'admin/dashboard.html';

    /* Resolve a path under /pages/ to an absolute URL. */
    function pageUrl(relative) {
        var path = window.location.pathname || '/';
        var base = '';
        var idx = path.indexOf('/pages/');
        if (idx !== -1) {
            base = path.substring(0, idx);
        } else {
            var last = path.lastIndexOf('/');
            base = last > 0 ? path.substring(0, last) : '';
        }
        return base + '/pages/' + relative;
    }

    function loginUrl() {
        return pageUrl('auth/login.html');
    }

    function protectPage(allowedRoles) {
        var roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

        if (!LearnovaSession.isAuthenticated() ||
            LearnovaSession.isBlocked() ||
            !LearnovaSession.requireRole(roles)) {
            var redirect = window.location.pathname + window.location.search;
            window.location.href = loginUrl() + '?redirect=' + encodeURIComponent(redirect);
            return false;
        }
        return true;
    }

    function redirectToDashboard() {
        var destination = DASHBOARDS[LearnovaSession.primaryRole()] || 'auth/login.html';
        window.location.href = pageUrl(destination);
    }

    return {
        pageUrl: pageUrl,
        loginUrl: loginUrl,
        protectPage: protectPage,
        redirectToDashboard: redirectToDashboard
    };
})();
