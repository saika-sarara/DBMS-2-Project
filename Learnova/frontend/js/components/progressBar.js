/* ==========================================================================
   Learnova Progress Bar (window.LearnovaProgressBar)
   Renders a track + fill using the dashboard's progress bar classes.
   ========================================================================== */

window.LearnovaProgressBar = (function () {
    'use strict';

    function render(percent) {
        var value = Number(percent) || 0;
        value = Math.max(0, Math.min(100, value));
        return '' +
            '<div class="dash-progress-track">' +
                '<div class="dash-progress-fill" style="width: ' + value + '%;"></div>' +
            '</div>';
    }

    return { render: render };
})();
