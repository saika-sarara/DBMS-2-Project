/* ==========================================================================
   Learnova Course Card (window.LearnovaCourseCard)
   Shared card structure: category visual block, difficulty badge, tag + rating,
   title, author, and lesson/module meta. Lock/prerequisite states are layered
   on by the parent renderer (see .locked-card in the page stylesheets).
   ========================================================================== */

window.LearnovaCourseCard = (function () {
    'use strict';

    var DEFAULT_IMAGE = 'backend';

    var CATEGORY_ICONS = {
        frontend: 'fa-code',
        backend: 'fa-database',
        datascience: 'fa-chart-simple',
        data: 'fa-chart-simple',
        machinelearning: 'fa-robot',
        ai: 'fa-brain'
    };

    function iconFor(image) {
        return CATEGORY_ICONS[String(image || '').toLowerCase()] || 'fa-graduation-cap';
    }

    function labelFor(image) {
        var key = String(image || '').toLowerCase();
        var labels = {
            frontend: 'Frontend',
            backend: 'Backend',
            datascience: 'Data Science',
            data: 'Data Science',
            machinelearning: 'Machine Learning',
            ai: 'AI & ML'
        };
        return labels[key] || 'Learning';
    }

    function difficultyBadge(difficulty) {
        if (!difficulty) return '';
        return '<span class="difficulty-badge difficulty-' + LearnovaHelpers.escapeHtml(String(difficulty).toLowerCase()) + '">' +
            LearnovaHelpers.escapeHtml(difficulty) + '</span>';
    }

    function render(course) {
        if (!course) return '';
        var image = course.image || DEFAULT_IMAGE;
        var tag = course.tag || course.category || 'General';
        var title = LearnovaHelpers.escapeHtml(course.title || 'Untitled Course');
        var author = LearnovaHelpers.escapeHtml(course.author ? 'By ' + course.author : '');

        var metaBits = [];
        if (course.moduleCount) metaBits.push(course.moduleCount + ' modules');
        if (course.lessonCount) metaBits.push(course.lessonCount + ' lessons');
        var meta = metaBits.length ? '<p class="card-meta">' + LearnovaHelpers.escapeHtml(metaBits.join(' · ')) + '</p>' : '';

        return '' +
            '<article class="course-card">' +
                '<div class="card-image-block" data-course="' + LearnovaHelpers.escapeHtml(image) + '">' +
                    '<i class="fa-solid ' + iconFor(image) + '"></i>' +
                    '<span>' + labelFor(image) + '</span>' +
                '</div>' +
                '<div class="card-content-block">' +
                    '<div class="card-tags-row">' +
                        '<span class="tag-pill">' + LearnovaHelpers.escapeHtml(tag) + '</span>' +
                        LearnovaRatingStars.render(course.rating) +
                    '</div>' +
                    difficultyBadge(course.difficulty) +
                    '<h3 class="card-title">' + title + '</h3>' +
                    '<p class="card-author">' + author + '</p>' +
                    meta +
                '</div>' +
            '</article>';
    }

    return { render: render };
})();
