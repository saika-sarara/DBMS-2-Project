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

    function create(message, email) {
        return LearnovaApiClient.post('/notifications', { message: message, email: email });
    }

    return {
        list: list,
        markRead: markRead,
        create: create
    };
})();
