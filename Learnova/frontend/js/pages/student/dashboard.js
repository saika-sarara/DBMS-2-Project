/* ==========================================================================
   Student Dashboard App - Page Templates + Slide/Fade Transitions
   Sub-navigation is fully JS-driven; no page reloads.
   ========================================================================== */
(function () {
    'use strict';

    var appContent = document.getElementById('app-content');
    if (!appContent) return;

    /* ---------- Learning Track Data ---------- */
    const tracks = {
        databaseEngineer: {
            name: 'Database Engineer',
            icon: 'fa-solid fa-database',
            accent: 'db-engineer',
            courses: [
                'SQL Fundamentals',
                'Advanced SQL & Optimization',
                'Graph Databases (Neo4j)',
                'Data Warehousing & ETL'
            ]
        }
    };

    /* Track cards for the Dashboard "Your Tracks" section */
    function trackCardsHtml() {
        return Object.keys(tracks).map(function (key) {
            var track = tracks[key];
            var items = track.courses.map(function (course) {
                return '<li class="track-course-item"><i class="fa-solid fa-lock"></i>' + course + '</li>';
            }).join('');
            return '<article class="track-card">' +
                '<div class="track-body">' +
                    '<div class="card-head">' +
                        '<h3 class="track-title">' + track.name + '</h3>' +
                        '<span class="badge">' + track.courses.length + ' Courses</span>' +
                    '</div>' +
                    '<ul class="track-courses">' + items + '</ul>' +
                '</div>' +
            '</article>';
        }).join('');
    }

    /* Track blocks for the Progress "By Track" view */
    function trackProgressHtml() {
        return Object.keys(tracks).map(function (key) {
            var track = tracks[key];
            var items = track.courses.map(function (course) {
                return '<div class="track-progress-course">' +
                    '<span class="track-progress-dot"></span>' +
                    '<span class="track-progress-name">' + course + '</span>' +
                    '<span class="progress-tag">Not Started</span>' +
                '</div>';
            }).join('');
            return '<div class="track-progress-block">' +
                '<div class="track-progress-head">' +
                    '<div class="progress-icon"><i class="' + track.icon + '"></i></div>' +
                    '<div class="progress-info">' +
                        '<div class="progress-title">' + track.name + '</div>' +
                        '<div class="progress-meta">' + track.courses.length + ' courses, 0% complete</div>' +
                    '</div>' +
                '</div>' +
                '<div class="track-progress-courses">' + items + '</div>' +
            '</div>';
        }).join('');
    }

    /* ---------- Page Templates (JS innerHTML injection) ---------- */

    var pages = {
        dashboard: '' +
            '<h1 class="page-title">Dashboard</h1>' +
            '<p class="subtitle">Welcome back, Sarah. Keep up the great momentum!</p>' +

            '<div class="dash-grid">' +

                /* -------- Left Column (65%) -------- */
                '<div class="dash-col-left">' +

                    /* Block 1: Dark tile - Continue Learning */
                    '<section class="dash-hero">' +
                        '<span class="dash-hero-kicker">COURSE</span>' +
                        '<h2 class="dash-hero-title">Modern React &amp; TypeScript</h2>' +
                        '<button class="dash-hero-btn">Continue Learning</button>' +
                        '<p class="dash-hero-track">Part of the Frontend Track</p>' +
                    '</section>' +

                    /* Block 3: Learning Stats (2x2 grid) */
                    '<section class="dash-card">' +
                        '<h3 class="dash-card-title">Your Learning Stats</h3>' +
                        '<div class="dash-stats-grid">' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num">6</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-book-open"></i> Enrolled Courses</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num">3</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-clock-rotate-left"></i> In Progress</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num">2</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-check"></i> Completed</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num">2</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-award"></i> Certificates Earned</div>' +
                            '</div>' +
                        '</div>' +
                    '</section>' +

                    /* Block 5: Keep Learning (dashed card) */
                    '<section class="dash-card dash-labs">' +
                        '<h3>Keep Learning</h3>' +
                        '<p>Continue mastering new skills. Ready to dive into your next course?</p>' +
                        '<div class="dash-labs-actions">' +
                            '<button class="dash-outline-btn">Python for Data Science</button>' +
                            '<button class="dash-outline-btn">Spring Boot Essentials</button>' +
                            '<button class="dash-outline-btn">View All Courses</button>' +
                        '</div>' +
                    '</section>' +

                    /* Block 6: Become an Instructor (spec 1.3) */
                    '<section class="dash-card">' +
                        '<h3 class="dash-card-title">Become an Instructor</h3>' +
                        '<div id="instructorRequestCta"></div>' +
                    '</section>' +
                '</div>' +

                /* -------- Right Column (35%) -------- */
                '<div class="dash-col-right">' +

                    /* Block 2: My Activity */
                    '<section class="dash-card">' +
                        '<div class="dash-activity-top">' +
                            '<span class="dash-avatar">S</span>' +
                            '<div class="dash-activity-stats">' +
                                '<div class="dash-activity-item"><span class="dash-activity-label">Daily Streak</span><span class="dash-activity-value">0 days</span></div>' +
                                '<div class="dash-activity-item"><span class="dash-activity-label">Total Courses</span><span class="dash-activity-value">6</span></div>' +
                            '</div>' +
                        '</div>' +
                        '<div class="dash-activity-counts">' +
                            '<span>2 Completed</span>' +
                            '<span>3 In Progress</span>' +
                        '</div>' +
                        '<div class="dash-activity-progress">' +
                            '<div class="dash-activity-progress-label">Progress towards profile mastery</div>' +
                            '<div class="dash-progress-track"><div class="dash-progress-fill" style="width: 60%;"></div></div>' +
                        '</div>' +
                    '</section>' +

                    /* Block 4: Certificates Earned */
                    '<section class="dash-card dash-leader">' +
                        '<h3 class="dash-card-title">Certificates Earned</h3>' +
                        '<div class="dash-circle">2</div>' +
                        '<p>You\'re 2/2. Complete more tracks to earn new badges.</p>' +
                        '<div class="dash-progress-row">' +
                            '<span class="dash-xp">2 XP</span>' +
                            '<span>2 / 5 XP</span>' +
                        '</div>' +
                        '<div class="dash-progress-track"><div class="dash-progress-fill" style="width: 40%;"></div></div>' +
                    '</section>' +

                    /* Block 7: Notifications (spec 10, in-app only) */
                    '<section class="dash-card">' +
                        '<h3 class="dash-card-title">Notifications</h3>' +
                        '<div id="notificationsBox"></div>' +
                    '</section>' +
                '</div>' +
            '</div>',

        catalog: '' +
            '<h1 class="page-title">Course Catalog</h1>' +
            '<p class="subtitle">Discover new skills and add them to your learning tracks.</p>' +

            '<div class="catalog-toolbar">' +
                '<div class="catalog-search">' +
                    '<i class="fa-solid fa-magnifying-glass"></i>' +
                    '<input type="text" placeholder="Search by title or instructor...">' +
                '</div>' +
                '<select>' +
                    '<option>Category</option>' +
                    '<option>Frontend</option>' +
                    '<option>Data Science</option>' +
                    '<option>UX Design</option>' +
                    '<option>Backend</option>' +
                '</select>' +
                '<select>' +
                    '<option>Difficulty</option>' +
                    '<option>Beginner</option>' +
                    '<option>Medium</option>' +
                    '<option>Hard</option>' +
                '</select>' +
            '</div>' +

            '<div class="course-grid">' +
                '<article class="course-card bundle-card">' +
                    '<div class="card-image-block" data-course="backend"><span>[ Track Thumbnail ]</span></div>' +
                    '<div class="card-content-block">' +
                        '<div class="card-tags-row">' +
                            '<span class="tag-pill">Beginner</span>' +
                            '<span class="rating-star">★ 4.7</span>' +
                        '</div>' +
                        '<h3 class="card-title"><a class="card-title-link" href="course-detail.html?course=database-design">' + tracks.databaseEngineer.name + ' Track</a></h3>' +
                        '<p class="card-author">4 courses · SQL, query optimization, Neo4j graphs, and ETL pipelines — end to end.</p>' +
                        '<div class="card-footer-row">' +
                            '<button class="btn-enroll">Enroll in Track</button>' +
                        '</div>' +
                    '</div>' +
                '</article>' +

                '<article class="course-card">' +
                    '<div class="card-image-block" data-course="frontend"><span>[ Course Thumbnail ]</span></div>' +
                    '<div class="card-content-block">' +
                        '<div class="card-tags-row">' +
                            '<span class="tag-pill">Intermediate</span>' +
                            '<span class="rating-star">★ 4.8</span>' +
                        '</div>' +
                        '<h3 class="card-title"><a class="card-title-link" href="course-detail.html?course=modern-react">Modern React &amp; TypeScript</a></h3>' +
                        '<p class="card-author">By Sarah Jenkins</p>' +
                        '<div class="card-progress">' +
                            '<span class="status-text">In Progress</span>' +
                            '<div class="card-progress-track"><div class="card-progress-fill" style="width: 33%;"></div></div>' +
                            '<span class="card-percent">33%</span>' +
                        '</div>' +
                    '</div>' +
                '</article>' +

                '<article class="course-card locked-card">' +
                    '<div class="card-image-block blur-content" data-course="frontend"><span>[ Course Thumbnail ]</span></div>' +
                    '<div class="card-content-block blur-content">' +
                        '<div class="card-tags-row">' +
                            '<span class="tag-pill">Advanced</span>' +
                            '<span class="rating-star">★ 4.6</span>' +
                        '</div>' +
                        '<h3 class="card-title"><a class="card-title-link" href="course-detail.html?course=advanced-data-structures">Advanced Data Structures</a></h3>' +
                        '<p class="card-author">Trees, heaps, and graph algorithms.</p>' +
                    '</div>' +
                    '<div class="locked-overlay">' +
                        '<div class="lock-icon-wrapper">' +
                            '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#6b7bf2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>' +
                        '</div>' +
                        '<span class="prereq-badge">Prerequisite Required</span>' +
                        '<a class="bypass-link" href="course-detail.html?course=advanced-data-structures">View course &amp; bypass exam</a>' +
                    '</div>' +
                '</article>' +

                '<article class="course-card">' +
                    '<div class="card-image-block" data-course="datascience"><span>[ Course Thumbnail ]</span></div>' +
                    '<div class="card-content-block">' +
                        '<div class="card-tags-row">' +
                            '<span class="tag-pill">Intermediate</span>' +
                            '<span class="rating-star">★ 4.7</span>' +
                        '</div>' +
                        '<h3 class="card-title"><a class="card-title-link" href="course-detail.html?course=python-for-data-science">Python for Data Science</a></h3>' +
                        '<p class="card-author">By Priya Sharma</p>' +
                        '<div class="card-progress">' +
                            '<span class="status-text completed">Completed</span>' +
                            '<div class="card-progress-track"><div class="card-progress-fill" style="width: 100%;"></div></div>' +
                            '<span class="card-percent">100%</span>' +
                        '</div>' +
                    '</div>' +
                '</article>' +
            '</div>',

        progress: '' +
            '<h1 class="page-title">Learning Progress</h1>' +
            '<p class="subtitle">Track your journey and consistency over time.</p>' +

            '<div class="progress-section">' +
            '<div class="progress-toggle">' +
                '<button class="active" data-view="courses">By Course</button>' +
                '<button data-view="tracks">By Track</button>' +
            '</div>' +

            '<div class="progress-list">' +
                '<div class="progress-item">' +
                    '<div class="progress-icon">M</div>' +
                    '<div class="progress-info">' +
                        '<div class="progress-title">Modern React &amp; TypeScript</div>' +
                        '<div class="progress-meta">Frontend, 6 lessons</div>' +
                    '</div>' +
                    '<div class="progress-bar-lg"><div class="progress-fill-lg" style="width: 33%;"></div></div>' +
                    '<span class="progress-tag">33% done</span>' +
                '</div>' +

                '<div class="progress-item">' +
                    '<div class="progress-icon">P</div>' +
                    '<div class="progress-info">' +
                        '<div class="progress-title">Python for Data Science</div>' +
                        '<div class="progress-meta">Data Science, 6 lessons</div>' +
                    '</div>' +
                    '<div class="progress-bar-lg"><div class="progress-fill-lg" style="width: 100%;"></div></div>' +
                    '<span class="progress-tag completed">Completed</span>' +
                '</div>' +

                '<div class="progress-item">' +
                    '<div class="progress-icon">U</div>' +
                    '<div class="progress-info">' +
                        '<div class="progress-title">UI/UX Principles</div>' +
                        '<div class="progress-meta">UX Design, 6 lessons</div>' +
                    '</div>' +
                    '<div class="progress-bar-lg"><div class="progress-fill-lg" style="width: 20%;"></div></div>' +
                    '<span class="progress-tag">20% done</span>' +
                '</div>' +
            '</div>' +

            '<div class="track-progress-section">' + trackProgressHtml() + '</div>' +
            '</div>',

        certificates: '' +
            '<h1 class="page-title">My Certificates</h1>' +
            '<p class="subtitle">View and download your earned credentials.</p>' +

            '<div class="certificates-toolbar">' +
                '<div class="cert-search">' +
                    '<i class="fa-solid fa-magnifying-glass"></i>' +
                    '<input type="text" placeholder="Search certificates...">' +
                '</div>' +
            '</div>' +

            '<div class="certificate-card">' +
                '<div class="certificate-icon"><i class="fa-solid fa-award"></i></div>' +
                '<div class="certificate-body">' +
                    '<div class="certificate-kicker">Track Certificate</div>' +
                    '<div class="certificate-title">Frontend Dev</div>' +
                    '<div class="certificate-code">LRV-8K3F-9Q2X</div>' +
                    '<div class="certificate-date">Issued June 2026</div>' +
                '</div>' +
                '<div class="certificate-actions">' +
                    '<button class="btn-outline">View</button>' +
                    '<button class="btn-outline"><i class="fa-solid fa-download"></i> Download</button>' +
                '</div>' +
            '</div>' +

            '<div class="certificate-card">' +
                '<div class="certificate-icon"><i class="fa-solid fa-award"></i></div>' +
                '<div class="certificate-body">' +
                    '<div class="certificate-kicker">Course Certificate</div>' +
                    '<div class="certificate-title">Python for Data Science</div>' +
                    '<div class="certificate-code">LRV-7M1P-4T6W</div>' +
                    '<div class="certificate-date">Issued May 2026</div>' +
                '</div>' +
                '<div class="certificate-actions">' +
                    '<button class="btn-outline">View</button>' +
                    '<button class="btn-outline"><i class="fa-solid fa-download"></i> Download</button>' +
                '</div>' +
            '</div>' +

            '<p class="certificate-verify-note">' +
                '<i class="fa-solid fa-shield-halved"></i> Every certificate carries a unique LRV-XXXX-XXXX code and can be verified through the public certificate lookup (vw_certificate_verification).' +
            '</p>'
    };

    /* ---------- Initial Render ---------- */

    var initial = document.body.dataset.page || 'dashboard';
    if (!pages[initial]) initial = 'dashboard';
    var currentPage = initial;

    appContent.innerHTML = pages[currentPage];
    appContent.classList.add('page-active');
    populatePage(currentPage);

    /* ---------- Dynamic widgets (spec 1.3, 10) ---------- */

    function renderInstructorCta() {
        var box = document.getElementById('instructorRequestCta');
        if (!box) return;

        var user = LearnovaSession.currentUser();
        var isInstructor = LearnovaSession.hasRole(LearnovaConstants.ROLES.INSTRUCTOR);
        var REQ_KEY = LearnovaConstants.INSTRUCTOR_REQUEST_KEY;

        if (isInstructor) {
            box.innerHTML = '<p class="cta-line">You hold the <strong>Instructor</strong> role.</p>' +
                '<a class="btn btn-outline btn-sm" href="../instructor/dashboard.html">Open Instructor Dashboard</a>';
            return;
        }

        var requests = [];
        try { requests = JSON.parse(localStorage.getItem(REQ_KEY) || '[]'); } catch (err) { requests = []; }
        var mine = requests.filter(function (r) { return r.email === (user && user.email); })[0];

        if (mine && mine.status === LearnovaConstants.INSTRUCTOR_REQUEST_STATUS.PENDING) {
            box.innerHTML = '<p class="cta-line">Your request is <strong>pending</strong>. An Admin will review it — you will be notified on approval or rejection.</p>';
            return;
        }
        if (mine && mine.status === LearnovaConstants.INSTRUCTOR_REQUEST_STATUS.APPROVED) {
            box.innerHTML = '<p class="cta-line">Request <strong>approved</strong>! You now have the Instructor role.</p>' +
                '<a class="btn btn-outline btn-sm" href="../instructor/dashboard.html">Open Instructor Dashboard</a>';
            return;
        }
        if (mine && mine.status === LearnovaConstants.INSTRUCTOR_REQUEST_STATUS.REJECTED) {
            box.innerHTML = '<p class="cta-line">Your request was <strong>rejected</strong> by an Admin.</p>' +
                '<button class="btn btn-primary btn-sm" data-action="become-instructor">Request Again</button>';
            return;
        }

        box.innerHTML = '<p class="cta-line">Self-registration only creates Student accounts. Want to teach? Submit a request — an Admin approves it and grants the Instructor role.</p>' +
            '<button class="btn btn-primary btn-sm" data-action="become-instructor">Request Instructor Role</button>';
    }

    function submitInstructorRequest() {
        var user = LearnovaSession.currentUser();
        var REQ_KEY = LearnovaConstants.INSTRUCTOR_REQUEST_KEY;
        var requests = [];
        try { requests = JSON.parse(localStorage.getItem(REQ_KEY) || '[]'); } catch (err) { requests = []; }
        if (user) {
            requests.push({
                id: Date.now(),
                email: user.email,
                name: user.name,
                status: LearnovaConstants.INSTRUCTOR_REQUEST_STATUS.PENDING,
                created_at: new Date().toISOString()
            });
            localStorage.setItem(REQ_KEY, JSON.stringify(requests));
        }
        renderInstructorCta();
    }

    function renderNotifications() {
        var box = document.getElementById('notificationsBox');
        if (!box) return;

        var items = [];
        try { items = JSON.parse(localStorage.getItem(LearnovaConstants.NOTIFICATIONS_KEY) || '[]'); } catch (err) { items = []; }

        if (!items.length) {
            box.innerHTML = '<p class="cta-line muted">No notifications yet. You\'ll see course updates, certificate issuances, and admin decisions here.</p>';
            return;
        }

        var html = items.slice(0, 5).map(function (n) {
            var when = new Date(n.created_at);
            var label = isNaN(when.getTime()) ? '' : when.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            return '<div class="notif-item">' +
                '<span class="notif-bullet' + (n.is_read ? ' read' : '') + '"></span>' +
                '<div>' +
                    '<div class="notif-message">' + n.message + '</div>' +
                    '<div class="notif-time">' + label + '</div>' +
                '</div>' +
            '</div>';
        }).join('');

        box.innerHTML = html;
    }

    function populatePage(page) {
        if (page === 'dashboard') {
            renderInstructorCta();
            renderNotifications();
        }
    }

    /* ---------- Navigation ---------- */

    function setActive(page) {
        var tabs = document.querySelectorAll('.secondary-nav .tab');
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.toggle('active', tabs[i].getAttribute('data-page') === page);
        }
    }

    var transitioning = false;

    function showPage(page) {
        if (page === currentPage || transitioning || !pages[page]) return;
        transitioning = true;

        /* 1. Exit: fade/slide current content out */
        appContent.classList.add('page-exit');

        setTimeout(function () {
            /* 2. Swap content */
            appContent.innerHTML = pages[page];
            appContent.classList.remove('page-exit');

            /* 3. Enter state: off-screen above, no transition */
            appContent.classList.add('page-enter');
            populatePage(page);

            /* 4. Settle into the active state with a springy ease */
            setTimeout(function () {
                appContent.classList.remove('page-enter');
                appContent.classList.add('page-active');
            }, 10);

            currentPage = page;
            setActive(page);
            window.scrollTo(0, 0);
            transitioning = false;
        }, 300);
    }

    document.addEventListener('click', function (event) {
        var reqBtn = event.target.closest('[data-action="become-instructor"]');
        if (reqBtn) {
            event.preventDefault();
            submitInstructorRequest();
            return;
        }

        var trigger = event.target.closest('[data-page]');
        if (trigger) {
            event.preventDefault();
            showPage(trigger.getAttribute('data-page'));
            return;
        }

        var toggleBtn = event.target.closest('.progress-toggle button[data-view]');
        if (toggleBtn) {
            var section = toggleBtn.closest('.progress-section');
            if (!section) return;
            var byCourse = toggleBtn.getAttribute('data-view') === 'courses';
            var courseList = section.querySelector('.progress-list');
            var trackSection = section.querySelector('.track-progress-section');
            if (courseList) courseList.style.display = byCourse ? '' : 'none';
            if (trackSection) trackSection.style.display = byCourse ? 'none' : '';
            var buttons = section.querySelectorAll('.progress-toggle button');
            for (var i = 0; i < buttons.length; i++) {
                buttons[i].classList.toggle('active', buttons[i] === toggleBtn);
            }
        }
    });

    setActive(currentPage);
})();
