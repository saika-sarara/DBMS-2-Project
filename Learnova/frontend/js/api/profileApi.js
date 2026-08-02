/* ==========================================================================
   Learnova Profile API (window.LearnovaProfileApi)
   Current-user profile via /api/v1/users/me. The backend wraps responses in
   {success, message, data, timestamp}; the offline mock returns the payload
   directly. Unwrap either shape.
   ========================================================================== */

window.LearnovaProfileApi = (function () {
    'use strict';

    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function me() {
        return unwrap(LearnovaApiClient.get('/users/me'));
    }

    /* payload: { firstName?, lastName?, currentPassword?, newPassword? } */
    function update(payload) {
        return unwrap(LearnovaApiClient.put('/users/me', payload || {}));
    }

    return {
        me: me,
        update: update
    };
})();
