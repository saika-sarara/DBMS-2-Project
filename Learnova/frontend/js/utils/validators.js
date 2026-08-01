/* ==========================================================================
   Learnova Validators (window.LearnovaValidators)
   Returns an array of error messages, or an empty array when valid.
   ========================================================================== */

window.LearnovaValidators = (function () {
    'use strict';

    function isEmail(str) {
        if (str == null) return false;
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(str).trim());
    }

    function isRequired(str) {
        return str != null && String(str).trim().length > 0;
    }

    function isLength(str, min, max) {
        var len = String(str == null ? '' : str).trim().length;
        if (min != null && len < min) return false;
        if (max != null && len > max) return false;
        return true;
    }

    function validateCourse(payload) {
        var errors = [];
        if (!payload) return ['Course payload is required.'];

        if (!isRequired(payload.title)) {
            errors.push('Course title is required.');
        } else if (!isLength(payload.title, 3, 120)) {
            errors.push('Course title must be between 3 and 120 characters.');
        }

        if (payload.track && LearnovaConstants.TRACKS.indexOf(payload.track) === -1) {
            errors.push('Course track must be one of the platform tracks.');
        }

        return errors;
    }

    function validateQuestion(question) {
        var errors = [];
        if (!question) return ['Question is required.'];

        if (!isRequired(question.text)) {
            errors.push('Question text is required.');
        }

        var options = question.options || [];
        if (!Array.isArray(options) || options.length !== 4) {
            errors.push('Question must have exactly 4 options.');
        } else {
            for (var i = 0; i < options.length; i++) {
                if (!isRequired(options[i])) {
                    errors.push('Option ' + String.fromCharCode(65 + i) + ' is required.');
                }
            }
        }

        return errors;
    }

    return {
        isEmail: isEmail,
        isRequired: isRequired,
        isLength: isLength,
        validateCourse: validateCourse,
        validateQuestion: validateQuestion
    };
})();
