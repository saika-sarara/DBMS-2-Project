/* ==========================================================================
   Learnova Notification API (window.LearnovaNotificationApi)
   In-app notifications (spec 10).
   ========================================================================== */

window.LearnovaNotificationApi = (function () {
    'use strict';

    function list() {
        return LearnovaApiClient.get('/notifications');
    }

    function markRead(id) {
        return LearnovaApiClient.put('/notifications/' + id + '/read');
    }

    function markAllRead() {
        return LearnovaApiClient.put('/notifications/read-all');
    }

    return {
        list: list,
        markRead: markRead,
        markAllRead: markAllRead
    };
})();
