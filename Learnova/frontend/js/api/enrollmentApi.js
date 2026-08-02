/* ==========================================================================
   Learnova Enrollment API (window.LearnovaEnrollmentApi)
   Thin mirror of the backend enrollment REST contract. Every rule lives in
   the database; the client only calls the routes below and unwraps the
   ApiResponse envelope ({success, message, data, timestamp}) so pages receive
   the payload (the same shape the offline mock returns).
   ========================================================================== */

window.LearnovaEnrollmentApi = (function () {
    'use strict';

    var R = LearnovaConstants.ENROLLMENT_ROUTES;

    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function path(template, params) {
        return template.replace(/:(\w+)/g, function (_, key) {
            return encodeURIComponent(params[key]);
        });
    }

    function enroll(courseId) {
        return unwrap(LearnovaApiClient.post(path(R.ENROLL_COURSE, { courseId: courseId })));
    }

    function enrollTrack(trackId) {
        return unwrap(LearnovaApiClient.post(path(R.ENROLL_TRACK, { trackId: trackId })));
    }

    function myCourses() {
        return unwrap(LearnovaApiClient.get(R.MY_COURSES));
    }

    function myTracks() {
        return unwrap(LearnovaApiClient.get(R.MY_TRACKS));
    }

    function courseAccess(courseId) {
        return unwrap(LearnovaApiClient.get(path(R.COURSE_ACCESS, { courseId: courseId })));
    }

    function stats() {
        return unwrap(LearnovaApiClient.get(R.STATS));
    }

    return {
        enroll: enroll,
        enrollTrack: enrollTrack,
        myCourses: myCourses,
        myTracks: myTracks,
        courseAccess: courseAccess,
        stats: stats
    };
})();
