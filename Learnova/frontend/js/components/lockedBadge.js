/* ==========================================================================
   Learnova Locked Badge (window.LearnovaLockedBadge)
   Overlay pill shown on cards whose course has unmet prerequisites.
   ========================================================================== */

window.LearnovaLockedBadge = (function () {
    'use strict';

    function render() {
        return '' +
            '<div class="locked-overlay">' +
                '<div class="lock-icon-wrapper">' +
                    '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#6b7bf2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>' +
                '</div>' +
                '<span class="prereq-badge">Prerequisite Required</span>' +
            '</div>';
    }

    return { render: render };
})();
