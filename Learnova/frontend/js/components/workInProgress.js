/* ==========================================================================
   Work-in-Progress banner (workInProgress.js)
   Marks a page that has no backend support yet. Include this script on the
   page so clicking it shows a clear "under construction" notice instead of a
   silently broken or mock-driven feature.
   ========================================================================== */
(function () {
    'use strict';

    var BANNER_TEXT =
        'This feature is under construction and not yet available on the platform.';

    function inject() {
        if (document.getElementById('learnova-wip-banner')) return;

        var style = document.createElement('style');
        style.textContent =
            '#learnova-wip-banner{' +
                'display:flex;align-items:center;gap:0.9rem;' +
                'padding:0.85rem 1.4rem;' +
                'background:#fff7e6;' +
                'border-bottom:1px solid #f0d9a8;' +
                'color:#7a5b1d;' +
                'font-family:\'Cormorant Garamond\',serif;' +
            '}' +
            '#learnova-wip-banner .wip-icon{font-size:1.35rem;}' +
            '#learnova-wip-banner .wip-text strong{display:block;font-size:1.2rem;line-height:1.2;}' +
            '#learnova-wip-banner .wip-text span{font-size:1.05rem;opacity:0.85;}';
        document.head.appendChild(style);

        var banner = document.createElement('div');
        banner.id = 'learnova-wip-banner';
        banner.innerHTML =
            '<span class="wip-icon"><i class="fa-solid fa-hammer"></i></span>' +
            '<div class="wip-text"><strong>Work in progress</strong><span>' + BANNER_TEXT + '</span></div>';

        var header = document.querySelector('.top-nav');
        if (header && header.parentNode) {
            header.parentNode.insertBefore(banner, header);
        } else {
            document.body.insertBefore(banner, document.body.firstChild);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', inject);
    } else {
        inject();
    }
})();
