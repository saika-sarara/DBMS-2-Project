/* ==========================================================================
   Learnova Notification API (window.LearnovaNotificationApi)
   In-app notifications (spec 10).
   ========================================================================== */

window.LearnovaNotificationApi = (function () {
    'use strict';

    /* The Spring Boot backend wraps these endpoints in ApiResponse, so every
       call unwraps `data` for the caller (same contract as the other API
       modules). */
    function unwrap(promise) {
        return promise.then(function (body) {
            if (body && typeof body === 'object' && 'data' in body) {
                return body.data;
            }
            return body;
        });
    }

    function list() {
        return unwrap(LearnovaApiClient.get('/notifications'));
    }

    function markRead(id) {
        return unwrap(LearnovaApiClient.put('/notifications/' + encodeURIComponent(id) + '/read'));
    }

    function markAllRead() {
        return unwrap(LearnovaApiClient.put('/notifications/read-all'));
    }

    return {
        list: list,
        markRead: markRead,
        markAllRead: markAllRead
    };
})();
