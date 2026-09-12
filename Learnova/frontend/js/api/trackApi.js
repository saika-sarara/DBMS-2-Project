window.LearnovaTrackApi = (function () {
    'use strict';

    function list() {
        return LearnovaApiClient.get('/tracks');
    }

    function get(trackId) {
        return LearnovaApiClient.get('/tracks/' + encodeURIComponent(trackId));
    }

    return {
        list: list,
        get: get
    };
})();
