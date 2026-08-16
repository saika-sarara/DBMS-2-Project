/* ==========================================================================
   Learnova Student Certificates Page
   --------------------------------------------------------------------------
   Current transitional behavior:

   PostgreSQL already owns course completion and certificate issuance.

   However, the Spring Certificate read/verification API has not yet been
   implemented.

   Therefore this page:

       - never fabricates certificate records
       - never fabricates certificate codes
       - never offers fake View/Download actions
       - uses real completed enrollments only
       - clearly distinguishes completion data from certificate data

   The real Certificate REST API will replace this transitional reader in the
   Certificate backend phase.
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


    /* ======================================================================
       Helpers
       ====================================================================== */

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


    function isCompleted(course) {
        return String(
            course &&
            course.status
                ? course.status
                : ''
        ).toLowerCase() ===
            'completed';
    }


    function formatDate(value) {
        if (!value) {
            return null;
        }


        var date =
            new Date(value);


        if (
            Number.isNaN(
                date.getTime()
            )
        ) {
            return null;
        }


        return date.toLocaleDateString(
            undefined,
            {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            }
        );
    }


    /* ======================================================================
       Page shell
       ====================================================================== */

    function renderShell() {
        clear(root);


        root.appendChild(
            createElement(
                'h1',
                'page-title',
                'My Certificates'
            )
        );


        root.appendChild(
            createElement(
                'p',
                'subtitle',
                'Certificates are issued automatically when learning requirements are completed.'
            )
        );


        var notice =
            createElement(
                'div',
                'certificate-verify-note'
            );


        var noticeIcon =
            createElement(
                'i',
                'fa-solid fa-circle-info'
            );


        var noticeText =
            document.createTextNode(
                ' Certificate download and verification are not exposed by the current backend API yet. Completed courses are shown below without fabricating certificate records.'
            );


        notice.appendChild(
            noticeIcon
        );

        notice.appendChild(
            noticeText
        );


        root.appendChild(
            notice
        );


        var content =
            createElement(
                'section',
                ''
            );

        content.id =
            'certificateContent';


        root.appendChild(
            content
        );
    }


    /* ======================================================================
       Loading
       ====================================================================== */

    function renderLoading() {
        var content =
            document.getElementById(
                'certificateContent'
            );

        if (!content) {
            return;
        }


        clear(content);


        var card =
            createElement(
                'div',
                'dash-card'
            );


        card.style.marginTop =
            '1.5rem';


        card.appendChild(
            createElement(
                'p',
                'cta-line muted',
                'Loading completed courses...'
            )
        );


        content.appendChild(card);
    }


    /* ======================================================================
       Empty state
       ====================================================================== */

    function renderEmpty() {
        var content =
            document.getElementById(
                'certificateContent'
            );

        if (!content) {
            return;
        }


        clear(content);


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


        icon.appendChild(
            createElement(
                'i',
                'fa-solid fa-award'
            )
        );


        wrapper.appendChild(icon);


        wrapper.appendChild(
            createElement(
                'h3',
                '',
                'No completed courses yet'
            )
        );


        wrapper.appendChild(
            createElement(
                'p',
                '',
                'Complete a course to become eligible for its automatically issued certificate.'
            )
        );


        var browse =
            createElement(
                'a',
                'btn-outline',
                'Browse Catalog'
            );

        browse.href =
            'catalog.html';

        browse.style.marginTop =
            '1.2rem';


        wrapper.appendChild(
            browse
        );


        content.appendChild(
            wrapper
        );
    }


    /* ======================================================================
       Error state
       ====================================================================== */

    function renderError() {
        var content =
            document.getElementById(
                'certificateContent'
            );

        if (!content) {
            return;
        }


        clear(content);


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


        icon.appendChild(
            createElement(
                'i',
                'fa-solid fa-triangle-exclamation'
            )
        );


        wrapper.appendChild(icon);


        wrapper.appendChild(
            createElement(
                'h3',
                '',
                'Completion data unavailable'
            )
        );


        wrapper.appendChild(
            createElement(
                'p',
                '',
                'Your completed courses could not be loaded.'
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

        retry.dataset.action =
            'retry-certificates';

        retry.style.marginTop =
            '1.2rem';


        wrapper.appendChild(
            retry
        );


        content.appendChild(
            wrapper
        );
    }


    /* ======================================================================
       Completed-course card
       ====================================================================== */

    function createCompletedCourseCard(course) {
        var card =
            createElement(
                'article',
                'certificate-card'
            );


        var icon =
            createElement(
                'div',
                'certificate-icon'
            );


        icon.appendChild(
            createElement(
                'i',
                'fa-solid fa-award'
            )
        );


        var body =
            createElement(
                'div',
                'certificate-body'
            );


        body.appendChild(
            createElement(
                'div',
                'certificate-kicker',
                'Completed Course'
            )
        );


        body.appendChild(
            createElement(
                'div',
                'certificate-title',
                course.entityTitle ||
                'Untitled Course'
            )
        );


        var completionDate =
            formatDate(
                course.completedAt
            );


        body.appendChild(
            createElement(
                'div',
                'certificate-date',
                completionDate
                    ? 'Completed ' +
                      completionDate
                    : 'Course completed'
            )
        );


        var status =
            createElement(
                'span',
                'certificate-code',
                'Certificate record API pending'
            );


        body.appendChild(status);


        card.appendChild(icon);

        card.appendChild(body);


        return card;
    }


    /* ======================================================================
       Render completed courses
       ====================================================================== */

    function renderCompletedCourses(courses) {
        var content =
            document.getElementById(
                'certificateContent'
            );

        if (!content) {
            return;
        }


        var completed =
            courses.filter(
                isCompleted
            );


        if (!completed.length) {
            renderEmpty();
            return;
        }


        clear(content);


        var heading =
            createElement(
                'div',
                'section-heading'
            );


        heading.appendChild(
            createElement(
                'h2',
                '',
                'Completed Courses'
            )
        );


        content.appendChild(
            heading
        );


        var list =
            createElement(
                'div',
                'progress-list'
            );


        completed.forEach(
            function (course) {

                list.appendChild(
                    createCompletedCourseCard(
                        course
                    )
                );
            }
        );


        content.appendChild(list);
    }


    /* ======================================================================
       Load
       ====================================================================== */

    function load() {
        renderLoading();


        LearnovaEnrollmentApi
            .myCourses()

            .then(function (courses) {

                renderCompletedCourses(
                    Array.isArray(courses)
                        ? courses
                        : []
                );
            })

            .catch(function () {
                renderError();
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
                    '[data-action="retry-certificates"]'
                );


            if (retry) {
                load();
            }
        }
    );


    /* ======================================================================
       Start
       ====================================================================== */

    renderShell();

    load();

})();