/* ==========================================================================
   Learnova Navbar (window.LearnovaNavbar)
   Renders the top-nav header + role-aware secondary-nav tabs.
   ========================================================================== */

window.LearnovaNavbar = (function () {
    'use strict';

    var NAV_LINKS = {};
    NAV_LINKS[LearnovaConstants.ROLES.STUDENT] = [
        { label: 'Dashboard', href: 'dashboard.html' },
        { label: 'Catalog', href: 'catalog.html' },
        { label: 'Progress', href: 'progress.html' },
        { label: 'Certificates', href: 'certificates.html' }
    ];
    NAV_LINKS[LearnovaConstants.ROLES.INSTRUCTOR] = [
        { label: 'Dashboard', href: 'dashboard.html' },
        { label: 'Courses', href: 'courses.html' },
        { label: 'Quiz Bank', href: 'quiz-editor.html' }
    ];
    NAV_LINKS[LearnovaConstants.ROLES.ADMIN] = [
        { label: 'Dashboard', href: 'dashboard.html' },
        { label: 'Users', href: 'user-management.html' },
        { label: 'Roles', href: 'role-management.html' }
    ];

    function isActive(link, activePage) {
        if (!activePage) return false;
        var linkPath = link.href.split('?')[0].split('#')[0].replace(/\.html$/, '');
        var pagePath = String(activePage).split('?')[0].split('#')[0].replace(/\.html$/, '');
        return linkPath === pagePath;
    }

    function render(activePage, role) {
        var user = LearnovaSession.currentUser();
        var resolvedRole = role || (user && user.role) || LearnovaConstants.ROLES.STUDENT;
        var links = NAV_LINKS[resolvedRole] || NAV_LINKS[LearnovaConstants.ROLES.STUDENT];

        var tabs = links.map(function (link) {
            return '<a class="tab' + (isActive(link, activePage) ? ' active' : '') + '" href="' + link.href + '">' + link.label + '</a>';
        }).join('');

        return '' +
            '<header class="top-nav">' +
                '<a href="../../index.html" class="logo">Learnova</a>' +
                '<div class="header-actions">' +
                    '<div class="role-pill">' + resolvedRole + ' <i class="fa-solid fa-chevron-down"></i></div>' +
                    '<button class="icon-btn" aria-label="Notifications"><i class="fa-solid fa-bell"></i><span class="notif-dot"></span></button>' +
                    '<button class="profile-btn" aria-label="Profile"><i class="fa-solid fa-user"></i></button>' +
                '</div>' +
            '</header>' +
            '<nav class="secondary-nav">' + tabs + '</nav>';
    }

    return { render: render };
})();
