/* ==========================================================================
   Learnova Generic Helpers (window.LearnovaHelpers)
   ========================================================================== */

window.LearnovaHelpers = (function () {
    'use strict';

    function escapeHtml(str) {
        if (str == null) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function formatNumber(n) {
        if (n == null || isNaN(Number(n))) return '0';
        return Number(n).toLocaleString('en-US');
    }

    function getQueryParam(name) {
        var params = new URLSearchParams(window.location.search);
        return params.get(name);
    }

    function initialsOf(name) {
        if (!name) return '';
        return String(name).trim().split(/\s+/).slice(0, 2)
            .map(function (part) { return part.charAt(0).toUpperCase(); })
            .join('');
    }

    function capitalize(str) {
        if (!str) return '';
        return String(str).charAt(0).toUpperCase() + String(str).slice(1);
    }

    function debounce(fn, wait) {
        var timer = null;
        return function () {
            var context = this;
            var args = arguments;
            clearTimeout(timer);
            timer = setTimeout(function () {
                fn.apply(context, args);
            }, wait);
        };
    }

    return {
        escapeHtml: escapeHtml,
        formatNumber: formatNumber,
        getQueryParam: getQueryParam,
        initialsOf: initialsOf,
        capitalize: capitalize,
        debounce: debounce
    };
})();
