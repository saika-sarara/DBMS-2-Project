/* ==========================================================================
   Learnova Course Card (window.LearnovaCourseCard)
   ========================================================================== */

window.LearnovaCourseCard = (function () {
    'use strict';

    var CATEGORY_ICONS = {
        database: 'fa-database',
        sql: 'fa-database',
        backend: 'fa-server',
        frontend: 'fa-code',
        programming: 'fa-code',
        python: 'fa-brands fa-python',
        data: 'fa-chart-simple',
        datascience: 'fa-chart-simple',
        machinelearning: 'fa-robot',
        ai: 'fa-brain',
        security: 'fa-shield-halved',
        cloud: 'fa-cloud'
    };

    function escapeHtml(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function categoryKey(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]/g, '');
    }

    function iconFor(category, title) {
        var categoryText = categoryKey(category);
        var titleText = categoryKey(title);
        var combined = categoryText + titleText;
        var keys = Object.keys(CATEGORY_ICONS);

        for (var index = 0; index < keys.length; index += 1) {
            if (combined.indexOf(keys[index]) !== -1) {
                return CATEGORY_ICONS[keys[index]];
            }
        }

        return 'fa-graduation-cap';
    }

    function safeImageUrl(value) {
        if (!value) {
            return '';
        }

        try {
            var parsed = new URL(
                String(value),
                window.location.href
            );

            if (
                parsed.protocol === 'http:' ||
                parsed.protocol === 'https:'
            ) {
                return parsed.href;
            }
        } catch (error) {
            return '';
        }

        return '';
    }

    function formatRating(value) {
        var rating = Number(value);

        if (!Number.isFinite(rating)) {
            rating = 0;
        }

        return rating.toFixed(1);
    }

    function formatPublishedDate(value) {
        if (!value) {
            return '';
        }

        var date = new Date(value);

        if (Number.isNaN(date.getTime())) {
            return '';
        }

        return date.toLocaleDateString(
            undefined,
            {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            }
        );
    }

    function difficultyBadge(difficulty) {
        if (!difficulty) {
            return '';
        }

        var normalized = String(difficulty)
            .trim()
            .toLowerCase();

        return (
            '<span class="difficulty-badge difficulty-' +
            escapeHtml(normalized) +
            '">' +
            escapeHtml(normalized) +
            '</span>'
        );
    }

    /* Action visuals come straight from the backend card fields
       (locked / enrolled / completed / lockReason / cardStatus). The
       database decides access; the card only renders the state. */
    function actionLabel(course) {
        if (course.completed) {
            return {
                text: 'Completed',
                icon: 'fa-circle-check',
                state: 'completed'
            };
        }

        if (course.enrolled) {
            return {
                text: 'Continue Learning',
                icon: 'fa-circle-play',
                state: 'enrolled'
            };
        }

        if (course.locked) {
            return {
                text: 'Locked',
                icon: 'fa-lock',
                state: 'locked'
            };
        }

        return {
            text: 'Enroll',
            icon: 'fa-arrow-right',
            state: ''
        };
    }

    function actionFooter(course, href) {
        var action = actionLabel(course);
        var lockHint =
            course.locked && course.lockReason
                ? ' title="' + escapeHtml(course.lockReason) + '"'
                : '';

        return (
            '<div class="card-actions">' +
                '<a class="card-action-btn' +
                    (action.state ? ' card-action-' + action.state : '') +
                    '" href="' + escapeHtml(href || '#') + '"' +
                    lockHint +
                '>' +
                    '<i class="fa-solid ' + action.icon + '"></i> ' +
                    escapeHtml(action.text) +
                '</a>' +
            '</div>'
        );
    }

    function renderImage(course, categoryName) {
        var thumbnailUrl = safeImageUrl(
            course.thumbnailUrl
        );

        if (thumbnailUrl) {
            return (
                '<div class="card-image-block card-image-photo">' +
                    '<img class="card-thumbnail" src="' +
                    escapeHtml(thumbnailUrl) +
                    '" alt="' +
                    escapeHtml(course.title || 'Course thumbnail') +
                    '">' +
                '</div>'
            );
        }

        return (
            '<div class="card-image-block">' +
                '<i class="fa-solid ' +
                iconFor(categoryName, course.title) +
                '"></i>' +
                '<span>' +
                escapeHtml(categoryName) +
                '</span>' +
            '</div>'
        );
    }

    function render(course, options) {
        if (!course) {
            return '';
        }

        var opts = options || {};
        var bare = Boolean(opts.bare);

        var categoryName =
            course.categoryName ||
            course.category ||
            'Uncategorized';

        var title =
            course.title ||
            'Untitled Course';

        var description =
            course.shortDescription ||
            course.description ||
            'Course details will be available soon.';

        var rating =
            course.avgRating !== undefined
                ? course.avgRating
                : course.rating;

        var reviewCount =
            Number(course.reviewCount) || 0;

        var publishedDate = formatPublishedDate(
            course.publishedAt
        );

        var courseId =
            course.courseId !== undefined
                ? course.courseId
                : course.id;

        var detailHref = '';
        if (!bare) {
            detailHref = opts.detailHref;
            if (!detailHref && courseId !== undefined && courseId !== null) {
                detailHref =
                    'course-detail.html?course=' +
                    encodeURIComponent(courseId);
            }
        }

        var titleHtml =
            '<h3 class="card-title">' +
                escapeHtml(title) +
            '</h3>';

        if (!bare && detailHref) {
            titleHtml =
                '<h3 class="card-title">' +
                    '<a class="card-title-link" href="' +
                    escapeHtml(detailHref) +
                    '">' +
                    escapeHtml(title) +
                    '</a>' +
                '</h3>';
        }

        return (
            '<article class="course-card" data-course-id="' +
            escapeHtml(courseId || '') +
            '">' +
                renderImage(course, categoryName) +
                '<div class="card-content-block">' +
                    '<div class="card-tags-row">' +
                        '<span class="tag-pill">' +
                            escapeHtml(categoryName) +
                        '</span>' +
                        '<span class="rating-star" aria-label="Rating ' +
                            escapeHtml(formatRating(rating)) +
                            ' out of 5">' +
                            '<i class="fa-solid fa-star"></i> ' +
                            escapeHtml(formatRating(rating)) +
                            '<span class="review-count"> (' +
                                escapeHtml(reviewCount) +
                            ')</span>' +
                        '</span>' +
                    '</div>' +
                    difficultyBadge(course.difficulty) +
                    titleHtml +
                    '<p class="card-description">' +
                        escapeHtml(description) +
                    '</p>' +
                    (
                        publishedDate
                            ? '<p class="card-meta">' +
                                '<i class="fa-regular fa-calendar"></i> ' +
                                'Published ' +
                                escapeHtml(publishedDate) +
                              '</p>'
                            : ''
                    ) +
                    (
                        !bare
                            ? actionFooter(course, detailHref)
                            : ''
                    ) +
                '</div>' +
            '</article>'
        );
    }

    return {
        render: render
    };
})();