/* ==========================================================================
   Learnova Student Dashboard
   One page, one responsibility.

   Real data used here:

     GET /enrollments/my-courses
     GET /enrollments/my-tracks
     GET /instructor-requests/mine

   Catalogue, Progress and Certificates are separate pages.

   One optional request failing must never destroy the successful results
   returned by other requests.
   ========================================================================== */

(function () {
    'use strict';


    /* ======================================================================
       Bootstrap
       ====================================================================== */

    var target =
        document.getElementById('app-content');

    if (!target) {
        return;
    }


    var state = {
        courses: [],
        tracks: [],
        instructorRequest: null,

        courseFailed: false,
        trackFailed: false,
        instructorFailed: false
    };


    /* ======================================================================
       General helpers
       ====================================================================== */

    function esc(value) {
        return String(
            value === null ||
            value === undefined
                ? ''
                : value
        )
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }


    function percent(value) {
        var number =
            Number(value);

        if (!Number.isFinite(number)) {
            return 0;
        }

        return Math.max(
            0,
            Math.min(
                100,
                Math.round(number)
            )
        );
    }


    function completed(item) {
        return String(
            item &&
            item.status
                ? item.status
                : ''
        ).toLowerCase() === 'completed';
    }


    function firstName() {
        var user =
            LearnovaSession.currentUser();

        var name =
            user &&
            (
                user.fullName ||
                user.name
            );

        if (!name) {
            return 'Student';
        }

        return (
            String(name)
                .trim()
                .split(/\s+/)[0] ||
            'Student'
        );
    }


    /*
     * IMPORTANT:
     *
     * This wrapper prevents the old dashboard problem where:
     *
     *     one request fails
     *         ↓
     *     Promise.all rejects
     *         ↓
     *     successful data is discarded
     *
     * Every request now has its own success/failure result.
     */
    function safe(promise) {
        return promise
            .then(function (value) {
                return {
                    ok: true,
                    value: value
                };
            })
            .catch(function (error) {
                return {
                    ok: false,
                    error: error
                };
            });
    }


    /* ======================================================================
       Main dashboard template
       ====================================================================== */

    function stat(
        id,
        icon,
        label
    ) {
        return (
            '<div class="dash-stat">' +

                '<div ' +
                    'class="dash-stat-num" ' +
                    'id="' + id + '">' +
                    '0' +
                '</div>' +

                '<div class="dash-stat-label">' +

                    '<i class="fa-solid ' +
                        icon +
                    '"></i> ' +

                    esc(label) +

                '</div>' +

            '</div>'
        );
    }


    function renderShell() {
        target.innerHTML =

            '<h1 class="page-title">' +
                'Dashboard' +
            '</h1>' +

            '<p ' +
                'class="subtitle" ' +
                'id="dashboardGreeting">' +
                'Loading your learning overview...' +
            '</p>' +


            '<div class="dash-grid">' +


                /* ==========================================================
                   Left column
                   ========================================================== */

                '<div class="dash-col-left">' +


                    /* Continue Learning */

                    '<section class="dash-hero">' +

                        '<span class="dash-hero-kicker">' +
                            'Continue Learning' +
                        '</span>' +

                        '<div id="continueLearning"></div>' +

                    '</section>' +


                    /* Stats */

                    '<section class="dash-card">' +

                        '<h2 class="dash-card-title">' +
                            'Your Learning Stats' +
                        '</h2>' +

                        '<div class="dash-stats-grid">' +

                            stat(
                                'statEnrolled',
                                'fa-book-open',
                                'Enrolled Courses'
                            ) +

                            stat(
                                'statInProgress',
                                'fa-clock-rotate-left',
                                'In Progress'
                            ) +

                            stat(
                                'statCompleted',
                                'fa-circle-check',
                                'Completed'
                            ) +

                            stat(
                                'statTracks',
                                'fa-route',
                                'Joined Tracks'
                            ) +

                        '</div>' +

                    '</section>' +


                    /* Explore */

                    '<section class="dash-card dash-labs">' +

                        '<h2 class="dash-card-title">' +
                            'Explore Learnova' +
                        '</h2>' +

                        '<p>' +
                            'Catalogue, progress and certificates now live ' +
                            'on their own pages.' +
                        '</p>' +

                        '<div class="dash-labs-actions">' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="catalog.html">' +

                                '<i class="fa-solid fa-compass"></i> ' +
                                'Browse Catalog' +

                            '</a>' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="progress.html">' +

                                '<i class="fa-solid fa-chart-line"></i> ' +
                                'View Progress' +

                            '</a>' +

                        '</div>' +

                    '</section>' +


                    /* Instructor request */

                    '<section class="dash-card">' +

                        '<h2 class="dash-card-title">' +
                            'Become an Instructor' +
                        '</h2>' +

                        '<div id="instructorRequestCta">' +

                            '<p class="cta-line muted">' +
                                'Loading request status...' +
                            '</p>' +

                        '</div>' +

                    '</section>' +


                '</div>' +


                /* ==========================================================
                   Right column
                   ========================================================== */

                '<div class="dash-col-right">' +


                    /* Activity */

                    '<section class="dash-card">' +

                        '<h2 class="dash-card-title">' +
                            'My Activity' +
                        '</h2>' +

                        '<div class="dash-activity-top">' +

                            '<span ' +
                                'class="dash-avatar" ' +
                                'id="activityAvatar">' +
                                'S' +
                            '</span>' +

                            '<div class="dash-activity-stats">' +

                                '<div>' +

                                    '<div class="dash-activity-label">' +
                                        'Courses Completed' +
                                    '</div>' +

                                    '<div ' +
                                        'class="dash-activity-value" ' +
                                        'id="activityCompleted">' +
                                        '0' +
                                    '</div>' +

                                '</div>' +

                                '<div>' +

                                    '<div class="dash-activity-label">' +
                                        'Total Enrolled' +
                                    '</div>' +

                                    '<div ' +
                                        'class="dash-activity-value" ' +
                                        'id="activityEnrolled">' +
                                        '0' +
                                    '</div>' +

                                '</div>' +

                            '</div>' +

                        '</div>' +


                        '<div class="dash-activity-progress-label">' +
                            'Average course progress' +
                        '</div>' +

                        '<div class="dash-progress-row">' +

                            '<span>' +
                                'Progress' +
                            '</span>' +

                            '<span ' +
                                'class="dash-xp" ' +
                                'id="activityProgressText">' +
                                '0%' +
                            '</span>' +

                        '</div>' +

                        '<div class="dash-progress-track">' +

                            '<div ' +
                                'class="dash-progress-fill" ' +
                                'id="activityFill" ' +
                                'style="width: 0%">' +
                            '</div>' +

                        '</div>' +

                    '</section>' +


                    /* Quick links */

                    '<section class="dash-card">' +

                        '<h2 class="dash-card-title">' +
                            'Quick Links' +
                        '</h2>' +

                        '<div class="dash-labs-actions">' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="catalog.html">' +
                                'Catalog' +
                            '</a>' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="progress.html">' +
                                'Progress' +
                            '</a>' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="certificates.html">' +
                                'Certificates' +
                            '</a>' +

                            '<a ' +
                                'class="dash-outline-btn" ' +
                                'href="../common/profile.html">' +
                                'Profile' +
                            '</a>' +

                        '</div>' +

                    '</section>' +


                    /* Partial API error warning */

                    '<section ' +
                        'class="dash-card" ' +
                        'id="dashboardWarning" ' +
                        'hidden>' +
                    '</section>' +


                '</div>' +


            '</div>';
    }


    /* ======================================================================
       DOM helpers
       ====================================================================== */

    function setText(
        id,
        value
    ) {
        var node =
            document.getElementById(id);

        if (node) {
            node.textContent =
                value;
        }
    }


    /* ======================================================================
       Continue Learning
       ====================================================================== */

    function renderContinueLearning() {
        var box =
            document.getElementById(
                'continueLearning'
            );

        if (!box) {
            return;
        }


        if (state.courseFailed) {

            box.innerHTML =

                '<h2 class="dash-hero-title">' +
                    'Learning data unavailable' +
                '</h2>' +

                '<p class="dash-hero-track">' +
                    'Your enrollments could not be loaded.' +
                '</p>' +

                '<button ' +
                    'class="dash-hero-btn" ' +
                    'type="button" ' +
                    'data-action="retry-dashboard">' +
                    'Try Again' +
                '</button>';

            return;
        }


        var active =
            state.courses.filter(
                function (course) {
                    return !completed(course);
                }
            )[0];


        if (!active) {

            box.innerHTML =

                '<h2 class="dash-hero-title">' +
                    'Choose your next course' +
                '</h2>' +

                '<p class="dash-hero-track">' +
                    'You have no course currently in progress.' +
                '</p>' +

                '<a ' +
                    'class="dash-hero-btn" ' +
                    'href="catalog.html">' +
                    'Browse Catalog' +
                '</a>';

            return;
        }


        box.innerHTML =

            '<h2 class="dash-hero-title">' +
                esc(
                    active.entityTitle ||
                    'Course'
                ) +
            '</h2>' +

            '<p class="dash-hero-track">' +
                percent(active.progressPct) +
                '% complete' +
            '</p>' +

            '<a ' +
                'class="dash-hero-btn" ' +
                'href="course-detail.html?course=' +
                encodeURIComponent(
                    active.entityId
                ) +
                '">' +
                'Continue Course' +
            '</a>';
    }


    /* ======================================================================
       Statistics
       ====================================================================== */

    function renderStats() {
        var done =
            state.courses.filter(
                completed
            ).length;

        var active =
            state.courses.length -
            done;

        var average = 0;


        if (state.courses.length) {

            average =
                Math.round(

                    state.courses.reduce(
                        function (
                            sum,
                            course
                        ) {
                            return (
                                sum +
                                percent(
                                    course.progressPct
                                )
                            );
                        },
                        0
                    ) /

                    state.courses.length
                );
        }


        setText(
            'statEnrolled',
            state.courses.length
        );

        setText(
            'statInProgress',
            active
        );

        setText(
            'statCompleted',
            done
        );

        setText(
            'statTracks',
            state.tracks.length
        );


        setText(
            'activityCompleted',
            done
        );

        setText(
            'activityEnrolled',
            state.courses.length
        );

        setText(
            'activityProgressText',
            average + '%'
        );


        var fill =
            document.getElementById(
                'activityFill'
            );

        if (fill) {
            fill.style.width =
                average + '%';
        }


        var avatar =
            document.getElementById(
                'activityAvatar'
            );

        if (avatar) {
            avatar.textContent =
                firstName()
                    .charAt(0)
                    .toUpperCase();
        }
    }


    /* ======================================================================
       Instructor request widget
       ====================================================================== */

    function renderInstructorRequest() {
        var box =
            document.getElementById(
                'instructorRequestCta'
            );

        if (!box) {
            return;
        }


        if (
            LearnovaSession.hasRole(
                LearnovaConstants.ROLES.INSTRUCTOR
            )
        ) {

            box.innerHTML =

                '<p class="cta-line">' +
                    'You already have the ' +
                    '<strong>Instructor</strong> role.' +
                '</p>' +

                '<a ' +
                    'class="btn-outline" ' +
                    'href="../instructor/dashboard.html">' +
                    'Open Instructor Dashboard' +
                '</a>';

            return;
        }


        if (state.instructorFailed) {

            box.innerHTML =

                '<p class="cta-line muted">' +
                    'Instructor request status is ' +
                    'temporarily unavailable.' +
                '</p>';

            return;
        }


        var status =
            String(
                state.instructorRequest &&
                state.instructorRequest.status
                    ? state.instructorRequest.status
                    : ''
            ).toLowerCase();


        if (status === 'pending') {

            box.innerHTML =

                '<p class="cta-line">' +
                    'Your request is ' +
                    '<strong>pending</strong> Admin review.' +
                '</p>';

            return;
        }


        if (status === 'approved') {

            box.innerHTML =

                '<p class="cta-line">' +
                    'Your request was ' +
                    '<strong>approved</strong>.' +
                '</p>' +

                '<a ' +
                    'class="btn-outline" ' +
                    'href="../instructor/dashboard.html">' +
                    'Open Instructor Dashboard' +
                '</a>';

            return;
        }


        if (status === 'rejected') {

            box.innerHTML =

                '<p class="cta-line">' +
                    'Your previous request was rejected.' +
                '</p>' +

                '<button ' +
                    'class="btn-outline" ' +
                    'type="button" ' +
                    'data-action="request-instructor">' +
                    'Request Again' +
                '</button>';

            return;
        }


        box.innerHTML =

            '<p class="cta-line">' +
                'Want to teach? Submit a request ' +
                'for Admin approval.' +
            '</p>' +

            '<button ' +
                'class="btn-outline" ' +
                'type="button" ' +
                'data-action="request-instructor">' +
                'Request Instructor Role' +
            '</button>';
    }


    /* ======================================================================
       Partial failure warning
       ====================================================================== */

    function renderWarning() {
        var box =
            document.getElementById(
                'dashboardWarning'
            );

        if (!box) {
            return;
        }


        var failures = [];


        if (state.courseFailed) {
            failures.push(
                'course enrollments'
            );
        }


        if (state.trackFailed) {
            failures.push(
                'Track enrollments'
            );
        }


        if (state.instructorFailed) {
            failures.push(
                'instructor request status'
            );
        }


        if (!failures.length) {

            box.hidden = true;
            box.innerHTML = '';

            return;
        }


        box.hidden = false;

        box.innerHTML =

            '<h2 class="dash-card-title">' +
                'Partial data unavailable' +
            '</h2>' +

            '<p class="cta-line muted">' +
                'Could not load ' +
                esc(
                    failures.join(', ')
                ) +
                '. Other dashboard sections remain usable.' +
            '</p>';
    }


    /* ======================================================================
       Render all loaded data
       ====================================================================== */

    function render() {
        setText(
            'dashboardGreeting',
            'Welcome back, ' +
            firstName() +
            '. Here is your learning overview.'
        );


        renderContinueLearning();

        renderStats();

        renderInstructorRequest();

        renderWarning();
    }


    /* ======================================================================
       Load dashboard
       ====================================================================== */

    function load() {
        setText(
            'dashboardGreeting',
            'Loading your learning overview...'
        );


        var courseRequest =
            safe(
                LearnovaEnrollmentApi
                    .myCourses()
            );


        var trackRequest =
            safe(
                LearnovaEnrollmentApi
                    .myTracks()
            );


        var instructorRequest =
            window.LearnovaInstructorApi

                ? safe(
                    LearnovaInstructorApi
                        .myRequest()
                )

                : Promise.resolve({
                    ok: false
                });


        return Promise.all([
            courseRequest,
            trackRequest,
            instructorRequest
        ])
            .then(function (results) {

                var courseResult =
                    results[0];

                var trackResult =
                    results[1];

                var instructorResult =
                    results[2];


                state.courses =
                    courseResult.ok &&
                    Array.isArray(
                        courseResult.value
                    )

                        ? courseResult.value

                        : [];


                state.tracks =
                    trackResult.ok &&
                    Array.isArray(
                        trackResult.value
                    )

                        ? trackResult.value

                        : [];


                state.instructorRequest =
                    instructorResult.ok

                        ? instructorResult.value

                        : null;


                state.courseFailed =
                    !courseResult.ok;

                state.trackFailed =
                    !trackResult.ok;

                state.instructorFailed =
                    !instructorResult.ok;


                render();
            });
    }


    /* ======================================================================
       Instructor request action
       ====================================================================== */

    function requestInstructor(
        button
    ) {
        if (
            !window.LearnovaInstructorApi
        ) {
            return;
        }


        button.disabled = true;

        button.textContent =
            'Submitting...';


        LearnovaInstructorApi
            .createRequest('')

            .then(function (request) {

                state.instructorRequest =
                    request;

                state.instructorFailed =
                    false;


                renderInstructorRequest();


                if (
                    window.LearnovaToast
                ) {
                    LearnovaToast.success(
                        'Instructor request submitted.'
                    );
                }
            })

            .catch(function (error) {

                button.disabled =
                    false;

                button.textContent =
                    'Request Instructor Role';


                if (
                    window.LearnovaToast
                ) {

                    LearnovaToast.error(

                        error &&
                        error.message

                            ? error.message

                            : 'Could not submit the request.'
                    );
                }
            });
    }


    /* ======================================================================
       Events
       ====================================================================== */

    document.addEventListener(
        'click',
        function (event) {

            var retry =
                event.target.closest(
                    '[data-action="retry-dashboard"]'
                );


            if (retry) {
                load();
                return;
            }


            var requestButton =
                event.target.closest(
                    '[data-action="request-instructor"]'
                );


            if (requestButton) {

                requestInstructor(
                    requestButton
                );
            }
        }
    );


    /* ======================================================================
       Start page
       ====================================================================== */

    renderShell();

    load();

})();