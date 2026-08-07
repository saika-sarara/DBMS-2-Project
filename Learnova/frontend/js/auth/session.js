/* ==========================================================================
   Learnova Session
   Keeps login session stable and normalizes backend roles/status for frontend.
   Backend roles: STUDENT / INSTRUCTOR / ADMIN
   Frontend roles: Student / Instructor / Admin
   ========================================================================== */

window.LearnovaSession = (function () {
    'use strict';

    var STORAGE_KEY = LearnovaConstants.SESSION_KEY;

    var ROLE_PRIORITY = [
        LearnovaConstants.ROLES.ADMIN,
        LearnovaConstants.ROLES.INSTRUCTOR,
        LearnovaConstants.ROLES.STUDENT
    ];

    function normalizeRole(role) {
        var value = String(role || '').trim();

        value = value.replace(/^ROLE_/i, '').toUpperCase();

        if (value === 'ADMIN') return LearnovaConstants.ROLES.ADMIN;
        if (value === 'INSTRUCTOR') return LearnovaConstants.ROLES.INSTRUCTOR;
        return LearnovaConstants.ROLES.STUDENT;
    }

    function normalizeRoles(user) {
        var rawRoles = [];

        if (user && Array.isArray(user.roles)) {
            rawRoles = user.roles;
        } else if (user && user.role) {
            rawRoles = [user.role];
        }

        var normalized = rawRoles
            .map(normalizeRole)
            .filter(function (role, index, arr) {
                return arr.indexOf(role) === index;
            });

        if (!normalized.length) {
            normalized.push(LearnovaConstants.ROLES.STUDENT);
        }

        return normalized;
    }

    function normalizeStatus(status) {
        var value = String(status || '').trim().toUpperCase();

        if (value === 'SUSPENDED') {
            return LearnovaConstants.ACCOUNT_STATUS.SUSPENDED;
        }

        if (value === 'BANNED' || value === 'DISABLED') {
            return LearnovaConstants.ACCOUNT_STATUS.BANNED;
        }

        return LearnovaConstants.ACCOUNT_STATUS.ACTIVE;
    }

    function pickPrimaryRole(roles) {
        for (var i = 0; i < ROLE_PRIORITY.length; i++) {
            if (roles.indexOf(ROLE_PRIORITY[i]) !== -1) {
                return ROLE_PRIORITY[i];
            }
        }
        return LearnovaConstants.ROLES.STUDENT;
    }

    function normalizeUser(user) {
        if (!user) return null;

        var roles = normalizeRoles(user);
        var fullName = user.fullName || user.name || '';

        return Object.assign({}, user, {
            id: user.id || user.userId || null,
            name: fullName,
            fullName: fullName,
            email: user.email || '',
            token: user.token || '',
            roles: roles,
            role: pickPrimaryRole(roles),
            status: normalizeStatus(user.status || user.accountStatus)
        });
    }

    function get() {
        try {
            var raw = localStorage.getItem(STORAGE_KEY);
            if (!raw) return null;

            var user = JSON.parse(raw);
            return normalizeUser(user);
        } catch (err) {
            console.error('LearnovaSession.get failed:', err);
            return null;
        }
    }

    function set(user) {
        try {
            var normalized = normalizeUser(user);
            localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
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

    function rolesOf(user) {
        return normalizeRoles(user);
    }

    function currentRoles() {
        return rolesOf(get());
    }

    function isBlocked() {
        var user = get();
        if (!user) return false;

        return user.status === LearnovaConstants.ACCOUNT_STATUS.SUSPENDED ||
            user.status === LearnovaConstants.ACCOUNT_STATUS.BANNED;
    }

    function hasRole(role) {
        return rolesOf(get()).indexOf(normalizeRole(role)) !== -1;
    }

    function requireRole(roles) {
        var allowed = Array.isArray(roles) ? roles : [roles];
        allowed = allowed.map(normalizeRole);

        var mine = rolesOf(get());

        for (var i = 0; i < mine.length; i++) {
            if (allowed.indexOf(mine[i]) !== -1) {
                return true;
            }
        }

        return false;
    }

    function primaryRole() {
        var user = get();
        return user ? user.role : null;
    }

    function isMockToken(token) {
        return /^demo-token-/i.test(String(token || ''));
    }

    function refreshFromServer() {
        var user = get();

        if (!user || !user.token || isMockToken(user.token)) {
            return Promise.resolve(user);
        }

        if (!window.LearnovaAuthApi || typeof LearnovaAuthApi.me !== 'function') {
            return Promise.resolve(user);
        }

        return LearnovaAuthApi.me()
            .then(function (profile) {
                if (!profile) return user;

                var refreshed = normalizeUser(Object.assign({}, user, profile, {
                    token: user.token
                }));

                set(refreshed);
                return refreshed;
            })
            .catch(function () {
                return user;
            });
    }

    return {
        get: get,
        set: set,
        clear: clear,
        isAuthenticated: isAuthenticated,
        currentUser: currentUser,
        currentRoles: currentRoles,
        isBlocked: isBlocked,
        hasRole: hasRole,
        requireRole: requireRole,
        primaryRole: primaryRole,
        refreshFromServer: refreshFromServer
    };
})();