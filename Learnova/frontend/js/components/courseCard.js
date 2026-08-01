/* ==========================================================================
   Learnova Course Card (window.LearnovaCourseCard)
   Academos-style card: image block, tag + rating, title, author.
   Note: no enrolled-count or price/footer row in the design.
   ========================================================================== */

window.LearnovaCourseCard = (function () {
    'use strict';

    var DEFAULT_IMAGE = 'backend';

    function render(course) {
        if (!course) return '';
        var image = course.image || DEFAULT_IMAGE;
        var tag = course.tag || course.category || 'General';
        var title = LearnovaHelpers.escapeHtml(course.title || 'Untitled Course');
        var author = LearnovaHelpers.escapeHtml(course.author ? 'By ' + course.author : '');

        return '' +
            '<article class="course-card">' +
                '<div class="card-image-block" data-course="' + LearnovaHelpers.escapeHtml(image) + '"><span>[ Course Thumbnail ]</span></div>' +
                '<div class="card-content-block">' +
                    '<div class="card-tags-row">' +
                        '<span class="tag-pill">' + LearnovaHelpers.escapeHtml(tag) + '</span>' +
                        LearnovaRatingStars.render(course.rating) +
                    '</div>' +
                    '<h3 class="card-title">' + title + '</h3>' +
                    '<p class="card-author">' + author + '</p>' +
                '</div>' +
            '</article>';
    }

    return { render: render };
})();
