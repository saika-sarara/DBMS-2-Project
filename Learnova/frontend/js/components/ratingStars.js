/* ==========================================================================
   Learnova Rating Stars (window.LearnovaRatingStars)
   Gold star display for a numeric rating, e.g. "★ 4.7".
   ========================================================================== */

window.LearnovaRatingStars = (function () {
    'use strict';

    function render(rating) {
        var value = typeof rating === 'number' ? rating : parseFloat(rating);
        if (isNaN(value)) value = 0;
        return '<span class="rating-star">★ ' + value.toFixed(1) + '</span>';
    }

    return { render: render };
})();
