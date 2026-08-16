/* ==========================================================================
   Learnova Student Progress Page
   --------------------------------------------------------------------------
   One page, one responsibility.

   Real backend data:

       GET /api/v1/enrollments/my-courses
       GET /api/v1/enrollments/my-tracks

   Progress percentages and completion states come directly from PostgreSQL
   through the Enrollment API.

   This page does not calculate learning progress itself.
   ========================================================================== */

(function () {
    'use strict';


    /* ======================================================================
       Bootstrap
       ====================================================================== */

    var root =
        document.getElementById('app-content');

    if (!root) {
        return;
    }


    var state = {
        courses: [],
        tracks: [],

        coursesFailed: false,
        tracksFailed: false,

        activeView: 'courses'
    };


    /* ======================================================================
       Helpers
       ====================================================================== */

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


    function normalizePercent(value) {
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


    function statusOf(item) {
        return String(
            item &&
            item.status
                ? item.status
                : ''
        ).toLowerCase();
    }


    function isCompleted(item) {
        return statusOf(item) === 'completed';
    }


    function statusLabel(item) {
        var status =
            statusOf(item);

        if (status === 'completed') {
            return 'Completed';
        }

        if (status === 'active') {
            return 'In Progress';
        }

        if (!status) {
            return 'Unknown';
        }

        return status
            .replace(/[_-]+/g, ' ')
            .replace(/\b\w/g, function (character) {
                return character.toUpperCase();
            });
    }


    function createElement(
        tagName,
        className,
        text
    ) {
        var node =
            document.createElement(tagName);

        if (className) {
            node.className =
                className;
        }

        if (
            text !== undefined &&
            text !== null
        ) {
            node.textContent =
                text;
        }

        return node;
    }


    function clear(node) {
        while (node.firstChild) {
            node.removeChild(
                node.firstChild
            );
        }
    }


    /* ======================================================================
       Static page shell
       ====================================================================== */

    function renderShell() {
        clear(root);


        var title =
            createElement(
                'h1',
                'page-title',
                'Learning Progress'
            );


        var subtitle =
            createElement(
                'p',
                'subtitle',
                'Track your course and learning-path progress.'
            );


        var toggle =
            createElement(
                'div',
                'progress-toggle'
            );


        var coursesButton =
            createElement(
                'button',
                'active',
                'Courses'
            );

        coursesButton.type =
            'button';

        coursesButton.dataset.view =
            'courses';


        var tracksButton =
            createElement(
                'button',
                '',
                'Tracks'
            );

        tracksButton.type =
            'button';

        tracksButton.dataset.view =
            'tracks';


        toggle.appendChild(
            coursesButton
        );

        toggle.appendChild(
            tracksButton
        );


        var coursesSection =
            createElement(
                'section',
                ''
            );

        coursesSection.id =
            'courseProgressSection';


        var tracksSection =
            createElement(
                'section',
                ''
            );

        tracksSection.id =
            'trackProgressSection';

        tracksSection.hidden =
            true;


        root.appendChild(title);

        root.appendChild(subtitle);

        root.appendChild(toggle);

        root.appendChild(
            coursesSection
        );

        root.appendChild(
            tracksSection
        );
    }


    /* ======================================================================
       Loading state
       ====================================================================== */

    function renderLoading() {
        var courses =
            document.getElementById(
                'courseProgressSection'
            );

        var tracks =
            document.getElementById(
                'trackProgressSection'
            );


        if (courses) {

            clear(courses);

            courses.appendChild(
                createLoadingCard(
                    'Loading course progress...'
                )
            );
        }


        if (tracks) {

            clear(tracks);

            tracks.appendChild(
                createLoadingCard(
                    'Loading Track progress...'
                )
            );
        }
    }


    function createLoadingCard(message) {
        var card =
            createElement(
                'div',
                'dash-card'
            );

        var text =
            createElement(
                'p',
                'cta-line muted',
                message
            );

        card.appendChild(text);

        return card;
    }


    /* ======================================================================
       Empty / error states
       ====================================================================== */

    function createEmptyState(
        iconClass,
        title,
        message,
        actionText,
        actionHref
    ) {
        var wrapper =
            createElement(
                'div',
                'empty-state'
            );


        var icon =
            createElement(
                'div',
                'empty-icon'
            );


        var iconGlyph =
            createElement(
                'i',
                iconClass
            );

        icon.appendChild(
            iconGlyph
        );


        var heading =
            createElement(
                'h3',
                '',
                title
            );


        var description =
            createElement(
                'p',
                '',
                message
            );


        wrapper.appendChild(icon);

        wrapper.appendChild(
            heading
        );

        wrapper.appendChild(
            description
        );


        if (
            actionText &&
            actionHref
        ) {

            var action =
                createElement(
                    'a',
                    'btn-outline',
                    actionText
                );

            action.href =
                actionHref;

            action.style.marginTop =
                '1.2rem';

            wrapper.appendChild(
                action
            );
        }


        return wrapper;
    }


    function createErrorState(
        title,
        message,
        retryTarget
    ) {
        var wrapper =
            createElement(
                'div',
                'empty-state'
            );


        var icon =
            createElement(
                'div',
                'empty-icon'
            );


        var iconGlyph =
            createElement(
                'i',
                'fa-solid fa-triangle-exclamation'
            );

        icon.appendChild(
            iconGlyph
        );


        wrapper.appendChild(icon);

        wrapper.appendChild(
            createElement(
                'h3',
                '',
                title
            )
        );

        wrapper.appendChild(
            createElement(
                'p',
                '',
                message
            )
        );


        var retry =
            createElement(
                'button',
                'btn-outline',
                'Try Again'
            );

        retry.type =
            'button';

        retry.dataset.retry =
            retryTarget;

        retry.style.marginTop =
            '1.2rem';


        wrapper.appendChild(retry);


        return wrapper;
    }


    /* ======================================================================
       Progress item
       ====================================================================== */

    function createProgressItem(
        item,
        type
    ) {
        var progress =
            normalizePercent(
                item.progressPct
            );


        var wrapper =
            createElement(
                'article',
                'progress-item'
            );


        var icon =
            createElement(
                'div',
                'progress-icon'
            );


        var iconGlyph =
            createElement(
                'i',
                type === 'track'
                    ? 'fa-solid fa-route'
                    : 'fa-solid fa-book-open'
            );

        icon.appendChild(
            iconGlyph
        );


        var info =
            createElement(
                'div',
                'progress-info'
            );


        var title;


        if (
            type === 'course' &&
            item.entityId !== undefined &&
            item.entityId !== null
        ) {

            title =
                createElement(
                    'a',
                    'progress-title',
                    item.entityTitle ||
                    'Untitled Course'
                );

            title.href =
                'course-detail.html?course=' +
                encodeURIComponent(
                    item.entityId
                );

        } else {

            title =
                createElement(
                    'div',
                    'progress-title',
                    item.entityTitle ||
                    'Untitled Track'
                );
        }


        var metaText =
            statusLabel(item) +
            ' · ' +
            progress +
            '% complete';


        var meta =
            createElement(
                'div',
                'progress-meta',
                metaText
            );


        info.appendChild(title);

        info.appendChild(meta);


        var progressBar =
            createElement(
                'div',
                'progress-bar-lg'
            );


        var progressFill =
            createElement(
                'div',
                'progress-fill-lg'
            );

        progressFill.style.width =
            progress + '%';

        progressBar.appendChild(
            progressFill
        );


        var tag =
            createElement(
                'span',
                'progress-tag',
                isCompleted(item)
                    ? 'Completed'
                    : progress + '%'
            );


        if (isCompleted(item)) {
            tag.classList.add(
                'completed'
            );
        }


        wrapper.appendChild(icon);

        wrapper.appendChild(info);

        wrapper.appendChild(
            progressBar
        );

        wrapper.appendChild(tag);


        return wrapper;
    }


    /* ======================================================================
       Course progress
       ====================================================================== */

    function renderCourses() {
        var section =
            document.getElementById(
                'courseProgressSection'
            );

        if (!section) {
            return;
        }


        clear(section);


        if (state.coursesFailed) {

            section.appendChild(
                createErrorState(
                    'Course progress unavailable',
                    'Your course enrollments could not be loaded.',
                    'courses'
                )
            );

            return;
        }


        if (!state.courses.length) {

            section.appendChild(
                createEmptyState(
                    'fa-solid fa-book-open',
                    'No enrolled courses',
                    'Enroll in a course to start tracking your progress.',
                    'Browse Catalog',
                    'catalog.html'
                )
            );

            return;
        }


        var heading =
            createElement(
                'div',
                'section-heading'
            );


        heading.appendChild(
            createElement(
                'h2',
                '',
                'Course Progress'
            )
        );


        section.appendChild(
            heading
        );


        var list =
            createElement(
                'div',
                'progress-list'
            );


        state.courses.forEach(
            function (course) {

                list.appendChild(
                    createProgressItem(
                        course,
                        'course'
                    )
                );
            }
        );


        section.appendChild(list);
    }


    /* ======================================================================
       Track progress
       ====================================================================== */

    function renderTracks() {
        var section =
            document.getElementById(
                'trackProgressSection'
            );

        if (!section) {
            return;
        }


        clear(section);


        if (state.tracksFailed) {

            section.appendChild(
                createErrorState(
                    'Track progress unavailable',
                    'Your Track enrollments could not be loaded.',
                    'tracks'
                )
            );

            return;
        }


        if (!state.tracks.length) {

            section.appendChild(
                createEmptyState(
                    'fa-solid fa-route',
                    'No joined Tracks',
                    'Your enrolled learning paths will appear here.',
                    null,
                    null
                )
            );

            return;
        }


        var heading =
            createElement(
                'div',
                'section-heading'
            );


        heading.appendChild(
            createElement(
                'h2',
                '',
                'Track Progress'
            )
        );


        section.appendChild(
            heading
        );


        var list =
            createElement(
                'div',
                'progress-list'
            );


        state.tracks.forEach(
            function (track) {

                list.appendChild(
                    createProgressItem(
                        track,
                        'track'
                    )
                );
            }
        );


        section.appendChild(list);
    }


    /* ======================================================================
       View switching
       ====================================================================== */

    function switchView(view) {
        state.activeView =
            view === 'tracks'
                ? 'tracks'
                : 'courses';


        var coursesSection =
            document.getElementById(
                'courseProgressSection'
            );

        var tracksSection =
            document.getElementById(
                'trackProgressSection'
            );


        if (coursesSection) {

            coursesSection.hidden =
                state.activeView !==
                'courses';
        }


        if (tracksSection) {

            tracksSection.hidden =
                state.activeView !==
                'tracks';
        }


        document
            .querySelectorAll(
                '.progress-toggle [data-view]'
            )
            .forEach(
                function (button) {

                    button.classList.toggle(
                        'active',
                        button.dataset.view ===
                        state.activeView
                    );
                }
            );
    }


    /* ======================================================================
       Data loading
       ====================================================================== */

    function loadCourses() {
        return safe(
            LearnovaEnrollmentApi
                .myCourses()
        )
            .then(function (result) {

                state.coursesFailed =
                    !result.ok;


                state.courses =
                    result.ok &&
                    Array.isArray(
                        result.value
                    )

                        ? result.value

                        : [];


                renderCourses();
            });
    }


    function loadTracks() {
        return safe(
            LearnovaEnrollmentApi
                .myTracks()
        )
            .then(function (result) {

                state.tracksFailed =
                    !result.ok;


                state.tracks =
                    result.ok &&
                    Array.isArray(
                        result.value
                    )

                        ? result.value

                        : [];


                renderTracks();
            });
    }


    function loadAll() {
        renderLoading();

        return Promise.all([
            loadCourses(),
            loadTracks()
        ]);
    }


    /* ======================================================================
       Events
       ====================================================================== */

    document.addEventListener(
        'click',
        function (event) {

            var viewButton =
                event.target.closest(
                    '[data-view]'
                );


            if (viewButton) {

                switchView(
                    viewButton.dataset.view
                );

                return;
            }


            var retry =
                event.target.closest(
                    '[data-retry]'
                );


            if (!retry) {
                return;
            }


            if (
                retry.dataset.retry ===
                'courses'
            ) {

                loadCourses();

                return;
            }


            if (
                retry.dataset.retry ===
                'tracks'
            ) {

                loadTracks();
            }
        }
    );


    /* ======================================================================
       Start
       ====================================================================== */

    renderShell();

    switchView('courses');

    loadAll();

})();