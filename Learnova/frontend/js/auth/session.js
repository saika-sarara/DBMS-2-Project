/* ==========================================================================
   Learnova Session (window.LearnovaSession)
   Persists the authenticated user in localStorage under the SESSION_KEY.
   Supports the RBAC model (spec 1.2): a single user holds one or more roles
   (e.g. Student + Instructor) and an account status of active / suspended /
   banned. Suspended or banned accounts are blocked from logging in.
   ========================================================================== */

window.LearnovaSession = (function () {
    'use strict';

    var STORAGE_KEY = LearnovaConstants.SESSION_KEY;

    /* Priority order used to pick a user's dashboard when they hold several
       roles at once (Admin > Instructor > Student). */
    var ROLE_PRIORITY = [
        LearnovaConstants.ROLES.ADMIN,
        LearnovaConstants.ROLES.INSTRUCTOR,
        LearnovaConstants.ROLES.STUDENT
    ];

    /* Demo user you can persist to exercise the authenticated flows:
       LearnovaSession.set(LearnovaSession.SAMPLE_USER); */
    var SAMPLE_USER = {
        id: 1,
        name: 'Sarah Jenkins',
        email: 'sarah.j@example.com',
        roles: [LearnovaConstants.ROLES.STUDENT],
        role: LearnovaConstants.ROLES.STUDENT,
        status: LearnovaConstants.ACCOUNT_STATUS.ACTIVE,
        token: 'demo-token-sarah'
    };

    function get() {
        try {
            var raw = localStorage.getItem(STORAGE_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch (err) {
            console.error('LearnovaSession.get failed:', err);
            return null;
        }
    }

    function set(user) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
        } catch (err) {
            console.error('LearnovaSession.set failed:', err);
        }
    }

    function clear() {
        try {
            localStorage.removeItem(STORAGE_KEY);
        } catch (err) {
            console.error('LearnovaSession.clear failed:', err);
        }
    }

    function isAuthenticated() {
        var user = get();
        return !!(user && user.token);
    }

    function currentUser() {
        return get();
    }

    /* Normalize a user object to a roles array (older sessions stored a
       single `role`). */
    function rolesOf(user) {
        if (!user) return [];
        if (Array.isArray(user.roles) && user.roles.length) return user.roles;
        return user.role ? [user.role] : [];
    }

    function currentRoles() {
        return rolesOf(get());
    }

    /* True when the account status is suspended or banned (cannot log in). */
    function isBlocked() {
        var user = get();
        if (!user) return false;
        var status = user.status || LearnovaConstants.ACCOUNT_STATUS.ACTIVE;
        return status === LearnovaConstants.ACCOUNT_STATUS.SUSPENDED ||
            status === LearnovaConstants.ACCOUNT_STATUS.BANNED;
    }

    function hasRole(role) {
        return rolesOf(get()).indexOf(role) !== -1;
    }

    function requireRole(roles) {
        var allowed = Array.isArray(roles) ? roles : [roles];
        var mine = rolesOf(get());
        for (var i = 0; i < mine.length; i++) {
            if (allowed.indexOf(mine[i]) !== -1) return true;
        }
        return false;
    }

    /* Highest-priority role held by the current user. */
    function primaryRole() {
        var mine = rolesOf(get());
        for (var p = 0; p < ROLE_PRIORITY.length; p++) {
            if (mine.indexOf(ROLE_PRIORITY[p]) !== -1) return ROLE_PRIORITY[p];
        }
        return null;
    }

    return {
        SAMPLE_USER: SAMPLE_USER,
        get: get,
        set: set,
        clear: clear,
        isAuthenticated: isAuthenticated,
        currentUser: currentUser,
        currentRoles: currentRoles,
        isBlocked: isBlocked,
        hasRole: hasRole,
        requireRole: requireRole,
        primaryRole: primaryRole
    };
})();
