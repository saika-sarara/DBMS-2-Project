/* ==========================================================================
   Learnova Shared Dashboard Header (window.LearnovaDashboardHeader)

   Progressively enhances the standard <header class="top-nav"> that every
   dashboard page shares (see pages/admin|instructor|student/*.html):

     <header class="top-nav">
         <a href="../../index.html" class="logo">Learnova</a>
         <div class="header-actions">
             <div class="role-pill">Role <i class="fa-solid fa-chevron-down"></i></div>
             <button class="icon-btn" aria-label="Notifications">...</button>
             <a class="profile-btn" href="../common/profile.html">...</a>
         </div>
     </header>

   Without touching that markup it adds:

     * role menu  - shows every role the signed-in user holds and lets them
                    switch to that role's dashboard (Admin / Instructor /
                    Student priority)
     * profile menu - name, email, "View profile" and a working "Sign out"
                      that clears the session and returns to the login page
     * notifications menu - latest in-app notifications (backend / mock)
     * consistent open/close behaviour: one menu open at a time, closes on
       outside click, on Escape, and re-opens toggle themselves

   Pages only need to include this file after routeGuard.js. The component
   injects its own scoped styles so no CSS edits are required.
   ========================================================================== */

window.LearnovaDashboardHeader = (function () {
    'use strict';

    var ROLES = LearnovaConstants.ROLES;

    var ROLE_DASHBOARDS = {};
    ROLE_DASHBOARDS[ROLES.ADMIN] = 'admin/dashboard.html';
    ROLE_DASHBOARDS[ROLES.INSTRUCTOR] = 'instructor/dashboard.html';
    ROLE_DASHBOARDS[ROLES.STUDENT] = 'student/dashboard.html';

    var STYLE_ID = 'learnova-dashboard-header-styles';
    var MENU_CLASS = 'dh-menu';
    var OPEN_CLASS = 'dh-open';

    var MENU_CSS = '' +
        'header.top-nav .dh-control { position: relative; }' +
        'header.top-nav .role-pill, ' +
        'header.top-nav .icon-btn, ' +
        'header.top-nav .profile-btn { cursor: pointer; }' +
        '.' + MENU_CLASS + ' { position: absolute; top: calc(100% + 10px); right: 0; ' +
        'z-index: 1000; min-width: 220px; max-width: 320px; padding: 0.5rem; ' +
        'background: #ffffff; color: #1800ad; border: 1px solid #eef2ff; ' +
        'border-radius: 12px; box-shadow: 0 12px 32px rgba(24,0,173,0.18); ' +
        'display: none; text-align: left; }' +
        '.' + MENU_CLASS + '.' + OPEN_CLASS + ' { display: block; }' +
        '.' + MENU_CLASS + ' .dh-menu-item { display: flex; align-items: center; gap: 0.6rem; ' +
        'width: 100%; padding: 0.55rem 0.75rem; border: none; background: none; ' +
        'color: inherit; font-size: 1rem; font-family: inherit; text-align: left; ' +
        'border-radius: 8px; cursor: pointer; text-decoration: none; }' +
        '.' + MENU_CLASS + ' .dh-menu-item:hover { background: #eef2ff; }' +
        '.' + MENU_CLASS + ' .dh-menu-item.active { color: #6b7bf2; font-weight: 600; }' +
        '.' + MENU_CLASS + ' .dh-menu-item .dh-spacer { flex: 1; }' +
        '.' + MENU_CLASS + ' .dh-separator { height: 1px; margin: 0.35rem 0.5rem; ' +
        'background: #eef2ff; }' +
        '.' + MENU_CLASS + ' .dh-menu-label { padding: 0.35rem 0.75rem 0.1rem; ' +
        'font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; ' +
        'color: #8b93b5; }' +
        '.' + MENU_CLASS + ' .dh-name { font-weight: 700; }' +
        '.' + MENU_CLASS + ' .dh-email { font-size: 0.85rem; color: #8b93b5; ' +
        'word-break: break-all; }' +
        '.' + MENU_CLASS + ' .dh-empty { padding: 0.75rem; color: #8b93b5; ' +
        'font-size: 0.9rem; }' +
        '.' + MENU_CLASS + ' .dh-signout { color: #c0392b; font-weight: 600; }' +
        '.' + MENU_CLASS + ' .dh-signout:hover { background: #fdecea; }';

    var openControl = null;

    function injectStyles() {
        if (document.getElementById(STYLE_ID)) {
            return;
        }
        var style = document.createElement('style');
        style.id = STYLE_ID;
        style.textContent = MENU_CSS;
        document.head.appendChild(style);
    }

    function makeMenu() {
        var menu = document.createElement('div');
        menu.className = MENU_CLASS;
        menu.setAttribute('role', 'menu');
        return menu;
    }

    function makeItem(label, onClick, isActive) {
        var item = document.createElement('button');
        item.type = 'button';
        item.className = 'dh-menu-item';
        if (isActive) {
            item.classList.add('active');
        }
        item.setAttribute('role', 'menuitem');
        item.innerHTML = label;
        item.addEventListener('click', onClick);
        return item;
    }

    function closeMenu() {
        if (openControl) {
            var menu = openControl._dhMenu;
            if (menu) {
                menu.classList.remove(OPEN_CLASS);
            }
            var trigger = openControl._dhTrigger;
            if (trigger) {
                trigger.setAttribute('aria-expanded', 'false');
            }
            openControl.classList.remove(OPEN_CLASS);
            openControl = null;
        }
    }

    function toggleMenu(control) {
        if (openControl === control && control._dhMenu.classList.contains(OPEN_CLASS)) {
            closeMenu();
            return;
        }
        closeMenu();
        control.classList.add(OPEN_CLASS);
        control._dhMenu.classList.add(OPEN_CLASS);
        control._dhTrigger.setAttribute('aria-expanded', 'true');
        openControl = control;
    }

    function bindMenuBehaviour(control, trigger, menu) {
        control._dhMenu = menu;
        control._dhTrigger = trigger;
        control.appendChild(menu);

        trigger.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            toggleMenu(control);
        });

        menu.addEventListener('click', function (event) {
            event.stopPropagation();
        });
    }

    function navigate(url) {
        if (url) {
            window.location.href = url;
        }
    }

    function signOut() {
        LearnovaSession.clear();
        if (window.LearnovaAuthApi && typeof LearnovaAuthApi.logout === 'function') {
            LearnovaAuthApi.logout().finally(function () {
                navigate(LearnovaRouteGuard.loginUrl());
            });
            return;
        }
        navigate(LearnovaRouteGuard.loginUrl());
    }

    /* ---------- Role menu ---------- */

    function renderRolePill(pill, user) {
        var roles = user ? LearnovaSession.rolesOf(user) : [];
        var current = user ? LearnovaSession.primaryRole() : null;

        var label = current || ROLES.STUDENT;
        var textNode = document.createTextNode(label + ' ');
        pill.innerHTML = '';
        pill.appendChild(textNode);
        var chevron = document.createElement('i');
        chevron.className = 'fa-solid fa-chevron-down';
        pill.appendChild(chevron);

        var menu = makeMenu();
        var headerItem = document.createElement('div');
        headerItem.className = 'dh-menu-label';
        headerItem.textContent = 'Switch role';
        menu.appendChild(headerItem);

        var offered = roles.length ? roles : [ROLES.STUDENT];

        offered.forEach(function (role) {
            var active = role === current;
            var check = active
                ? '<span class="dh-spacer"></span><i class="fa-solid fa-check"></i>'
                : '<span class="dh-spacer"></span>';
            var item = makeItem(
                role + check,
                function () {
                    if (!active) {
                        navigate(LearnovaRouteGuard.pageUrl(ROLE_DASHBOARDS[role]));
                    }
                },
                active
            );
            menu.appendChild(item);
        });

        pill.setAttribute('role', 'button');
        pill.setAttribute('aria-haspopup', 'true');
        pill.setAttribute('aria-expanded', 'false');
        pill.setAttribute('tabindex', '0');

        pill.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                toggleMenu(pill);
            } else if (event.key === 'Escape') {
                closeMenu();
            }
        });

        bindMenuBehaviour(pill, pill, menu);
    }

    /* ---------- Notifications menu ---------- */

    function renderNotifications(button, user) {
        var menu = makeMenu();
        menu.style.minWidth = '300px';

        var title = document.createElement('div');
        title.className = 'dh-menu-label';
        title.textContent = 'Notifications';
        menu.appendChild(title);

        var body = document.createElement('div');
        body.className = 'dh-empty';
        body.textContent = 'Loading notifications...';
        menu.appendChild(body);

        var loaded = false;

        function showEmpty() {
            body.textContent = 'No notifications yet. Course updates, certificate issuances, and admin decisions will appear here.';
        }

        if (user && window.LearnovaNotificationApi && typeof LearnovaNotificationApi.list === 'function') {
            LearnovaNotificationApi.list()
                .then(function (items) {
                    loaded = true;
                    var list = Array.isArray(items) ? items : [];
                    if (!list.length) {
                        showEmpty();
                        return;
                    }
                    menu.removeChild(body);
                    list.slice(0, 8).forEach(function (notification) {
                        var text = notification && (notification.message || notification.title)
                            ? (notification.message || notification.title)
                            : 'New notification';
                        var item = document.createElement('button');
                        item.type = 'button';
                        item.className = 'dh-menu-item';
                        item.textContent = text;
                        menu.appendChild(item);
                    });
                })
                .catch(function () {
                    showEmpty();
                });
        } else {
            showEmpty();
        }

        bindMenuBehaviour(button, button, menu);
    }

    /* ---------- Profile menu ---------- */

    function renderProfile(link, user) {
        var menu = makeMenu();

        var identity = document.createElement('div');
        identity.className = 'dh-menu-label';
        identity.style.padding = '0.35rem 0.75rem 0.4rem';
        identity.innerHTML = '' +
            '<div class="dh-name">' + escapeHtml((user && user.name) || 'Account') + '</div>' +
            '<div class="dh-email">' + escapeHtml((user && user.email) || '') + '</div>';
        menu.appendChild(identity);

        var separator = document.createElement('div');
        separator.className = 'dh-separator';
        menu.appendChild(separator);

        var profileItem = document.createElement('a');
        profileItem.className = 'dh-menu-item';
        profileItem.href = link.getAttribute('href') || 'profile.html';
        profileItem.innerHTML = '<i class="fa-solid fa-user"></i> View profile';
        menu.appendChild(profileItem);

        var signOutItem = document.createElement('button');
        signOutItem.type = 'button';
        signOutItem.className = 'dh-menu-item dh-signout';
        signOutItem.innerHTML = '<i class="fa-solid fa-right-from-bracket"></i> Sign out';
        signOutItem.addEventListener('click', signOut);
        menu.appendChild(signOutItem);

        link.setAttribute('role', 'button');
        link.setAttribute('aria-haspopup', 'true');
        link.setAttribute('aria-expanded', 'false');
        link.setAttribute('tabindex', '0');

        link.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                toggleMenu(link);
            } else if (event.key === 'Escape') {
                closeMenu();
            }
        });

        bindMenuBehaviour(link, link, menu);
    }

    function escapeHtml(value) {
        return String(value || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    /* ---------- Init ---------- */

    function init() {
        injectStyles();

        var header = document.querySelector('header.top-nav');
        if (!header) {
            return;
        }

        var actions = header.querySelector('.header-actions');
        if (!actions) {
            return;
        }

        var user = LearnovaSession.get();
        var pill = actions.querySelector('.role-pill');
        var notificationButton = actions.querySelector('button.icon-btn[aria-label="Notifications"]');
        var profileButton = actions.querySelector('a.profile-btn');

        if (pill) {
            renderRolePill(pill, user);
        }
        if (notificationButton) {
            renderNotifications(notificationButton, user);
        }
        if (profileButton) {
            renderProfile(profileButton, user);
        }

        document.addEventListener('click', function (event) {
            if (openControl && !openControl.contains(event.target)) {
                closeMenu();
            }
        });

        document.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') {
                closeMenu();
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    return {
        init: init
    };
})();
