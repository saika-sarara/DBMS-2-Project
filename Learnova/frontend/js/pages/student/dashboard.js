/* ==========================================================================
   Student Dashboard App - Page Templates + Slide/Fade Transitions
   Sub-navigation is fully JS-driven; no page reloads.
   All content is data-driven from the API layer (LearnovaApiClient), which
   talks to the real backend when available and falls back to the offline
   mock adapter on network errors. No hardcoded demo courses or tracks.
   ========================================================================== */
(function () {
    'use strict';

    var appContent = document.getElementById('app-content');
    if (!appContent) return;

    /* ---------- In-memory state (hydrated from the API layer) ---------- */

    var state = {
        courses: [],
        enrolled: [],
        certs: [],
        notifications: [],
        instructorRequest: null
    };

    /* The backend enrollment payloads (EnrollmentResponse) identify a course
       by numeric entityId while the catalog list is slug-keyed. Merge the two
       so the rest of the dashboard keeps working unchanged. */
    function toCourseView(enrollment) {
        var course = null;
        for (var i = 0; i < state.courses.length; i++) {
            if (String(state.courses[i].id) === String(enrollment.entityId) ||
                String(state.courses[i].slug) === String(enrollment.entityId)) { course = state.courses[i]; break; }
        }
        var prog = (course && course.progress) || {
            total: 0,
            done: 0,
            pct: Number(enrollment.progressPct) || 0
        };
        var completed = enrollment.status === 'completed' || !!(course && course.completed);
        return {
            id: enrollment.entityId,
            slug: (course && course.slug) || enrollment.entityId,
            title: enrollment.entityTitle,
            track: course && course.track,
            completed: completed,
            certCode: course && course.certCode,
            progress: prog
        };
    }

    function loadState() {
        return Promise.all([
            LearnovaCourseApi.list(),
            LearnovaEnrollmentApi.myCourses(),
            LearnovaCertificateApi.listByUser(),
            LearnovaNotificationApi.list(),
            LearnovaInstructorApi.myRequest()
        ]).then(function (results) {
            state.courses = results[0] || [];
            state.enrolled = (results[1] || []).map(toCourseView);
            state.certs = results[2] || [];
            state.notifications = results[3] || [];
            state.instructorRequest = results[4] || null;
        }).catch(function () { /* keep last known state */ });
    }

    /* ---------- Tiny helpers ---------- */

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    /* Course-detail links must carry the numeric id the backend resolves;
       fall back to the slug only for legacy/mock data. */
    function courseTarget(course) {
        return (course && course.id !== undefined && course.id !== null)
            ? course.id
            : (course && course.slug);
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function enrolledCourses() { return state.enrolled; }

    function inProgressCourses() {
        return state.enrolled.filter(function (c) { return !c.completed; });
    }

    function completedCourses() {
        return state.enrolled.filter(function (c) { return c.completed; });
    }

    function certCourses() {
        return state.enrolled.filter(function (c) { return c.certCode; });
    }

    function progressOf(course) {
        return (course && course.progress) || { total: 0, done: 0, pct: 0 };
    }

    function firstName() {
        var user = LearnovaSession.currentUser();
        if (user && user.name) return user.name.split(' ')[0];
        return 'there';
    }

    /* ---------- Empty state (reused across widgets) ---------- */
    function emptyNote(message) {
        return '<p class="empty-note"><i class="fa-solid fa-sparkles"></i> ' + message + '</p>';
    }

    /* ---------- Page Templates (JS innerHTML injection) ---------- */

    var pages = {
        dashboard: '' +
            '<h1 class="page-title">Dashboard</h1>' +
            '<p class="subtitle" id="greeting"></p>' +

            '<div class="dash-grid">' +

                /* -------- Left Column (65%) -------- */
                '<div class="dash-col-left">' +

                    /* Block 1: Dark tile - Continue Learning */
                    '<section class="dash-hero">' +
                        '<span class="dash-hero-kicker" id="heroKicker">COURSE</span>' +
                        '<div id="heroBody"></div>' +
                    '</section>' +

                    /* Block 3: Learning Stats (2x2 grid) */
                    '<section class="dash-card">' +
                        '<h3 class="dash-card-title">Your Learning Stats</h3>' +
                        '<div class="dash-stats-grid">' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num" id="statEnrolled">0</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-book-open"></i> Enrolled Courses</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num" id="statInProgress">0</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-clock-rotate-left"></i> In Progress</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num" id="statCompleted">0</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-check"></i> Completed</div>' +
                            '</div>' +
                            '<div class="dash-stat">' +
                                '<div class="dash-stat-num" id="statCerts">0</div>' +
                                '<div class="dash-stat-label"><i class="fa-solid fa-award"></i> Certificates Earned</div>' +
                            '</div>' +
                        '</div>' +
                    '</section>' +

                    /* Block 5: Keep Learning (dashed card) */
                    '<section class="dash-card dash-labs">' +
                        '<h3>Keep Learning</h3>' +
                        '<p>Continue mastering new skills. Ready to dive into your next course?</p>' +
                        '<div class="dash-labs-actions" id="keepLearningActions"></div>' +
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
                            '<span class="dash-avatar" id="activityAvatar">S</span>' +
                            '<div class="dash-activity-stats">' +
                                '<div class="dash-activity-item"><span class="dash-activity-label">Courses Completed</span><span class="dash-activity-value" id="activityCompleted">0</span></div>' +
                                '<div class="dash-activity-item"><span class="dash-activity-label">Total Enrolled</span><span class="dash-activity-value" id="activityEnrolled">0</span></div>' +
                            '</div>' +
                        '</div>' +
                        '<div class="dash-activity-counts" id="activityCounts"></div>' +
                        '<div class="dash-activity-progress">' +
                            '<div class="dash-activity-progress-label">Overall course completion</div>' +
                            '<div class="dash-progress-track"><div class="dash-progress-fill" id="activityFill" style="width: 0%;"></div></div>' +
                        '</div>' +
                    '</section>' +

                    /* Block 4: Certificates Earned */
                    '<section class="dash-card dash-leader">' +
                        '<h3 class="dash-card-title">Certificates Earned</h3>' +
                        '<div class="dash-circle" id="certCircle">0</div>' +
                        '<p id="certBlurb"></p>' +
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
            '<p class="subtitle">Discover published courses and add them to your learning journey.</p>' +

            '<div class="catalog-toolbar">' +
                '<div class="catalog-search">' +
                    '<i class="fa-solid fa-magnifying-glass"></i>' +
                    '<input type="text" id="catalogSearch" placeholder="Search by title, track, or description...">' +
                '</div>' +
            '</div>' +

            '<div class="course-grid" id="catalogGrid"></div>',

        progress: '' +
            '<h1 class="page-title">Learning Progress</h1>' +
            '<p class="subtitle">Track your journey and consistency over time.</p>' +

            '<div class="progress-section">' +
                '<div class="progress-toggle">' +
                    '<button class="active" data-view="courses">By Course</button>' +
                    '<button data-view="tracks">By Track</button>' +
                '</div>' +
                '<div class="progress-list" id="progressList"></div>' +
                '<div class="track-progress-section" id="trackProgress"></div>' +
            '</div>',

        certificates: '' +
            '<h1 class="page-title">My Certificates</h1>' +
            '<p class="subtitle">View and download your earned credentials.</p>' +

            '<div id="certificatesList"></div>' +

            '<p class="certificate-verify-note">' +
                '<i class="fa-solid fa-shield-halved"></i> Every certificate carries a unique LRV-XXXX-XXXX code and can be verified through the public certificate lookup (vw_certificate_verification).' +
            '</p>'
    };

    /* ---------- Dashboard widget renderers ---------- */

    function renderHero() {
        var body = document.getElementById('heroBody');
        var kicker = document.getElementById('heroKicker');
        if (!body) return;

        var current = inProgressCourses()[0];
        if (!current) {
            if (kicker) kicker.textContent = 'GET STARTED';
            body.innerHTML =
                '<h2 class="dash-hero-title">You\'re all set to start learning</h2>' +
                '<button class="dash-hero-btn" data-page="catalog">Browse the Catalog</button>' +
                '<p class="dash-hero-track">Enroll in a course to begin building your skills.</p>';
            return;
        }

        var prog = progressOf(current);
        if (kicker) kicker.textContent = 'COURSE';
        body.innerHTML =
            '<h2 class="dash-hero-title">' + esc(current.title) + '</h2>' +
            '<button class="dash-hero-btn" data-goto="course" data-course="' + esc(courseTarget(current)) + '">Continue Learning</button>' +
            '<p class="dash-hero-track">' +
                (current.track ? 'Part of the ' + esc(current.track) + ' Track &middot; ' : '') +
                prog.pct + '% complete' +
            '</p>';
    }

    function renderStats() {
        var enrolled = enrolledCourses();
        var inProgress = inProgressCourses();
        var completed = completedCourses();
        var certs = certCourses();

        setText('statEnrolled', String(enrolled.length));
        setText('statInProgress', String(inProgress.length));
        setText('statCompleted', String(completed.length));
        setText('statCerts', String(certs.length));
    }

    function renderKeepLearning() {
        var box = document.getElementById('keepLearningActions');
        if (!box) return;

        var current = inProgressCourses().slice(0, 3);
        var html = '';
        current.forEach(function (course) {
            html += '<button class="dash-outline-btn" data-goto="course" data-course="' + esc(courseTarget(course)) + '">' + esc(course.title) + '</button>';
        });
        html += '<button class="dash-outline-btn" data-page="catalog">View All Courses</button>';
        box.innerHTML = html || emptyNote('No courses in progress yet. Pick something from the catalog to get started.');
    }

    function renderActivity() {
        var user = LearnovaSession.currentUser();
        var avatar = document.getElementById('activityAvatar');
        if (avatar) avatar.textContent = (user && user.name) ? user.name.trim().charAt(0).toUpperCase() : 'S';

        var enrolled = enrolledCourses();
        var completed = completedCourses();
        setText('activityEnrolled', String(enrolled.length));
        setText('activityCompleted', String(completed.length));

        var counts = document.getElementById('activityCounts');
        if (counts) {
            counts.innerHTML =
                '<span>' + completed.length + ' Completed</span>' +
                '<span>' + inProgressCourses().length + ' In Progress</span>';
        }

        var fill = document.getElementById('activityFill');
        if (fill) {
            var pct = enrolled.length ? Math.round(completed.length / enrolled.length * 100) : 0;
            fill.style.width = pct + '%';
        }
    }

    function renderCertSummary() {
        var certs = certCourses();
        setText('certCircle', String(certs.length));
        var blurb = document.getElementById('certBlurb');
        if (blurb) {
            blurb.textContent = certs.length
                ? 'You\'ve earned ' + certs.length + ' certificate' + (certs.length > 1 ? 's' : '') + ' so far. Keep it up!'
                : 'Complete a course to earn your first certificate.';
        }
    }

    /* ---------- Catalog renderer ---------- */

    function renderCatalog(filter) {
        var grid = document.getElementById('catalogGrid');
        if (!grid) return;

        var query = (filter || '').trim().toLowerCase();
        var courses = state.courses.filter(function (c) {
            return c.status === LearnovaConstants.COURSE_STATUS.PUBLISHED;
        }).filter(function (c) {
            if (!query) return true;
            return (c.title + ' ' + (c.track || '') + ' ' + (c.description || '')).toLowerCase().indexOf(query) !== -1;
        });

        if (!courses.length) {
            grid.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-sparkles"></i></div>' +
                    '<h3>' + (query ? 'No courses match "' + esc(query) + '"' : 'No published courses yet') + '</h3>' +
                    '<p>' + (query
                        ? 'Try a different search term.'
                        : 'Instructors create courses and admins publish them. Check back soon for new learning paths.') +
                    '</p>' +
                '</div>';
            return;
        }

        grid.innerHTML = courses.map(function (course) {
            var link = 'course-detail.html?course=' + esc(courseTarget(course));
            return '<article class="course-card">' +
                '<div class="card-image-block"><span><i class="fa-solid fa-graduation-cap"></i></span></div>' +
                '<div class="card-content-block">' +
                    '<div class="card-tags-row">' +
                        '<span class="tag-pill">' + esc(course.track || 'Course') + '</span>' +
                        '<span class="tag-pill">' + esc(course.status) + '</span>' +
                    '</div>' +
                    '<h3 class="card-title"><a class="card-title-link" href="' + link + '">' + esc(course.title) + '</a></h3>' +
                    '<p class="card-author">' + esc(course.description || 'No description yet.') + '</p>' +
                    '<div class="card-footer-row">' +
                        '<a class="btn-enroll" href="' + link + '">View Course</a>' +
                    '</div>' +
                '</div>' +
            '</article>';
        }).join('');
    }

    /* ---------- Progress renderers ---------- */

    function progressItemHtml(course) {
        var prog = progressOf(course);
        var status = course.completed ? 'Completed' : (prog.total ? prog.pct + '% done' : 'Not Started');
        var meta = (course.track ? course.track + ' &middot; ' : '') + prog.total + ' lessons';
        return '<div class="progress-item">' +
            '<div class="progress-icon">' + esc(course.title.charAt(0).toUpperCase()) + '</div>' +
            '<div class="progress-info">' +
                '<div class="progress-title">' + esc(course.title) + '</div>' +
                '<div class="progress-meta">' + meta + '</div>' +
            '</div>' +
            '<div class="progress-bar-lg"><div class="progress-fill-lg" style="width: ' + prog.pct + '%;"></div></div>' +
            '<span class="progress-tag' + (course.completed ? ' completed' : '') + '">' + status + '</span>' +
        '</div>';
    }

    function renderProgress() {
        var list = document.getElementById('progressList');
        if (!list) return;

        var enrolled = enrolledCourses();
        list.innerHTML = enrolled.length
            ? enrolled.map(progressItemHtml).join('')
            : emptyNote('You haven\'t enrolled in any courses yet.');

        var trackBox = document.getElementById('trackProgress');
        if (!trackBox) return;

        if (!enrolled.length) {
            trackBox.innerHTML = emptyNote('Enroll in a course to start tracking progress by track.');
            return;
        }

        var byTrack = {};
        enrolled.forEach(function (course) {
            var key = course.track || 'Ungrouped';
            if (!byTrack[key]) byTrack[key] = [];
            byTrack[key].push(course);
        });

        trackBox.innerHTML = Object.keys(byTrack).map(function (trackName) {
            var courses = byTrack[trackName];
            var rows = courses.map(function (course) {
                var prog = progressOf(course);
                var status = course.completed ? 'Completed' : (prog.total ? prog.pct + '% done' : 'Not Started');
                return '<div class="track-progress-course">' +
                    '<span class="track-progress-dot"></span>' +
                    '<span class="track-progress-name">' + esc(course.title) + '</span>' +
                    '<span class="progress-tag' + (course.completed ? ' completed' : '') + '">' + status + '</span>' +
                '</div>';
            }).join('');
            return '<div class="track-progress-block">' +
                '<div class="track-progress-head">' +
                    '<div class="progress-icon"><i class="fa-solid fa-layer-group"></i></div>' +
                    '<div class="progress-info">' +
                        '<div class="progress-title">' + esc(trackName) + '</div>' +
                        '<div class="progress-meta">' + courses.length + ' course' + (courses.length > 1 ? 's' : '') + '</div>' +
                    '</div>' +
                '</div>' +
                '<div class="track-progress-courses">' + rows + '</div>' +
            '</div>';
        }).join('');
    }

    /* ---------- Certificates renderer ---------- */

    function renderCertificates() {
        var list = document.getElementById('certificatesList');
        if (!list) return;

        var certs = state.certs.length
            ? state.certs
            : state.enrolled.filter(function (c) { return c.certCode; }).map(function (c) {
                return { courseId: c.id !== undefined && c.id !== null ? c.id : c.slug, courseTitle: c.title, code: c.certCode };
            });

        if (!certs.length) {
            list.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-award"></i></div>' +
                    '<h3>No certificates yet</h3>' +
                    '<p>Pass the final quiz of a course and its completion unlocks a verified LRV certificate automatically.</p>' +
                '</div>';
            return;
        }

        list.innerHTML = certs.map(function (cert) {
            return '<div class="certificate-card">' +
                '<div class="certificate-icon"><i class="fa-solid fa-award"></i></div>' +
                '<div class="certificate-body">' +
                    '<div class="certificate-kicker">Course Certificate</div>' +
                    '<div class="certificate-title">' + esc(cert.courseTitle) + '</div>' +
                    '<div class="certificate-code">' + esc(cert.code) + '</div>' +
                    '<div class="certificate-date">Verified credential &middot; uniquely coded</div>' +
                '</div>' +
                '<div class="certificate-actions">' +
                    '<a class="btn-outline" href="course-detail.html?course=' + esc(cert.courseId) + '">View</a>' +
                    '<button class="btn-outline" data-action="download-cert" data-course="' + esc(cert.courseId) + '" data-code="' + esc(cert.code) + '"><i class="fa-solid fa-download"></i> Download</button>' +
                '</div>' +
            '</div>';
        }).join('');
    }

    function downloadCert(slug, code) {
        var course = null;
        for (var i = 0; i < state.courses.length; i++) {
            if (String(state.courses[i].id) === String(slug) ||
                String(state.courses[i].slug) === String(slug)) { course = state.courses[i]; break; }
        }
        var user = LearnovaSession.currentUser();
        var name = user && user.name ? user.name : 'Student';
        var title = course ? course.title : slug;
        var fileSlug = (course && course.slug) || slug;
        var text = 'Learnova Certificate\n===========================\n\n' +
            'This certifies that ' + name + ' has successfully completed the course:\n' +
            title + '\n\nVerification code: ' + code + '\n\n' +
            'This credential carries a unique LRV-XXXX-XXXX code verifiable through the public certificate lookup.';
        var blob = new Blob([text], { type: 'text/plain' });
        var link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = fileSlug + '-certificate.txt';
        document.body.appendChild(link);
        link.click();
        link.remove();
    }

    /* ---------- Generic widgets (spec 1.3, 10) ---------- */

    function renderInstructorCta() {
        var box = document.getElementById('instructorRequestCta');
        if (!box) return;

        var isInstructor = LearnovaSession.hasRole(LearnovaConstants.ROLES.INSTRUCTOR);

        if (isInstructor) {
            box.innerHTML = '<p class="cta-line">You hold the <strong>Instructor</strong> role.</p>' +
                '<a class="btn btn-outline btn-sm" href="../instructor/dashboard.html">Open Instructor Dashboard</a>';
            return;
        }

        var mine = state.instructorRequest;

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
        LearnovaInstructorApi.createRequest().then(function () {
            return loadState();
        }).then(function () {
            renderInstructorCta();
        }).catch(function (err) {
            LearnovaToast.error((err && err.message) || 'Could not submit your request.');
        });
    }

    function renderNotifications() {
        var box = document.getElementById('notificationsBox');
        if (!box) return;

        var items = state.notifications || [];

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

    function setText(id, value) {
        var node = document.getElementById(id);
        if (node) node.textContent = value;
    }

    function populatePage(page) {
        loadState().then(function () {
            if (page === 'dashboard') {
                setText('greeting', 'Welcome back, ' + firstName() + '. Keep up the great momentum!');
                renderHero();
                renderStats();
                renderKeepLearning();
                renderActivity();
                renderCertSummary();
                renderInstructorCta();
                renderNotifications();
            }
            if (page === 'catalog') {
                renderCatalog('');
                var search = document.getElementById('catalogSearch');
                if (search) {
                    search.addEventListener('input', function () {
                        renderCatalog(search.value);
                    });
                }
            }
            if (page === 'progress') {
                renderProgress();
            }
            if (page === 'certificates') {
                renderCertificates();
            }
        });
    }

    /* ---------- Initial Render ---------- */

    var initial = document.body.dataset.page || 'dashboard';
    if (!pages[initial]) initial = 'dashboard';
    var currentPage = initial;

    appContent.innerHTML = pages[currentPage];
    appContent.classList.add('page-active');
    populatePage(currentPage);

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

        var dlBtn = event.target.closest('[data-action="download-cert"]');
        if (dlBtn) {
            event.preventDefault();
            downloadCert(dlBtn.getAttribute('data-course'), dlBtn.getAttribute('data-code'));
            return;
        }

        var goto = event.target.closest('[data-goto="course"]');
        if (goto) {
            event.preventDefault();
            window.location.href = 'course-detail.html?course=' + encodeURIComponent(goto.getAttribute('data-course'));
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
