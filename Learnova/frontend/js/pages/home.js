/* ==========================================================================
   Home page (index.html)
   Loads the "Popular Courses" grid from the live public catalogue
   (GET /catalogue/courses?sort=popular). No login required: the backend
   endpoint is public. The mock never serves this route (strict rule: real
   features must not be mocked).
   ========================================================================== */

(function () {
    'use strict';

    var grid =
        document.getElementById('homePopularCourses');

    if (!grid) {
        return;
    }

    if (
        !window.LearnovaCourseApi ||
        !window.LearnovaCourseCard
    ) {
        grid.innerHTML =
            '<div class="home-catalog-state home-catalog-error">' +
                '<i class="fa-solid fa-triangle-exclamation"></i>' +
                '<p>Popular courses could not load.</p>' +
            '</div>';

        return;
    }

    function escapeHtml(value) {
        return String(
            value === null || value === undefined
                ? ''
                : value
        )
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function detailHref(course) {
        var courseId =
            course.courseId !== undefined && course.courseId !== null
                ? course.courseId
                : course.id;

        if (courseId === null || courseId === undefined) {
            return 'pages/student/catalog.html';
        }

        return (
            'pages/student/course-detail.html?course=' +
            encodeURIComponent(courseId)
        );
    }

    function renderCourses(courses) {
        if (!courses.length) {
            grid.innerHTML =
                '<div class="home-catalog-state">' +
                    '<i class="fa-solid fa-book-open"></i>' +
                    '<p>No published courses yet. Check back soon.</p>' +
                '</div>';

            return;
        }

        grid.innerHTML = courses
            .map(function (course) {
                var href = detailHref(course);

                return (
                    '<a class="home-card-link" href="' +
                    escapeHtml(href) +
                    '" aria-label="View course: ' +
                    escapeHtml(course.title || '') +
                    '">' +
                        LearnovaCourseCard.render(course, { bare: true }) +
                    '</a>'
                );
            })
            .join('');
    }

    function renderError(error) {
        var message =
            error && error.message
                ? error.message
                : 'Please try again later.';

        grid.innerHTML =
            '<div class="home-catalog-state home-catalog-error">' +
                '<i class="fa-solid fa-triangle-exclamation"></i>' +
                '<p>Popular courses are temporarily unavailable.</p>' +
                '<p class="home-catalog-detail">' +
                    escapeHtml(message) +
                '</p>' +
            '</div>';
    }

    LearnovaCourseApi
        .searchCatalogue({
            search: '',
            categoryId: '',
            difficulty: '',
            sort: 'popular',
            page: 0,
            size: 6
        })
        .then(function (pageData) {
            var courses = Array.isArray(pageData.content)
                ? pageData.content
                : [];

            renderCourses(courses);
        })
        .catch(function (error) {
            console.error(
                'Home popular courses failed:',
                error
            );

            renderError(error);
        });
})();
