/* ==========================================================================
   Learnova Route Guard
   Protects role pages and redirects users to the correct dashboard.
   ========================================================================== */

window.LearnovaRouteGuard = (function () {
    'use strict';

    var DASHBOARDS = {};
    DASHBOARDS[LearnovaConstants.ROLES.STUDENT] = 'student/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.INSTRUCTOR] = 'instructor/dashboard.html';
    DASHBOARDS[LearnovaConstants.ROLES.ADMIN] = 'admin/dashboard.html';

    function pageUrl(relative) {
        var path = window.location.pathname || '/';
        var base = '';

        var pagesIndex = path.indexOf('/pages/');

        if (pagesIndex !== -1) {
            base = path.substring(0, pagesIndex);
        } else {
            var lastSlash = path.lastIndexOf('/');
            base = lastSlash > 0 ? path.substring(0, lastSlash) : '';
        }

        return base + '/pages/' + relative;
    }

    function loginUrl() {
        return pageUrl('auth/login.html');
    }

    function protectPage(allowedRoles) {
        var roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

        if (!LearnovaSession.isAuthenticated()) {
            redirectToLogin();
            return false;
        }

        if (LearnovaSession.isBlocked()) {
            LearnovaSession.clear();
            redirectToLogin();
            return false;
        }

        if (!LearnovaSession.requireRole(roles)) {
            redirectToOwnDashboard();
            return false;
        }

        setTimeout(function () {
            LearnovaSession.refreshFromServer();
        }, 0);

        return true;
    }

    function redirectToLogin() {
        var redirect = window.location.pathname + window.location.search;
        window.location.href = loginUrl() + '?redirect=' + encodeURIComponent(redirect);
    }

    function redirectToOwnDashboard() {
        var role = LearnovaSession.primaryRole();

        if (!role) {
            redirectToLogin();
            return;
        }

        var destination = DASHBOARDS[role];

        if (!destination) {
            redirectToLogin();
            return;
        }

        var currentPath = window.location.pathname;
        var targetPath = pageUrl(destination);

        if (currentPath !== targetPath) {
            window.location.href = targetPath;
        }
    }

    function redirectToDashboard() {
        redirectToOwnDashboard();
    }

    return {
        pageUrl: pageUrl,
        loginUrl: loginUrl,
        protectPage: protectPage,
        redirectToDashboard: redirectToDashboard
    };
})();