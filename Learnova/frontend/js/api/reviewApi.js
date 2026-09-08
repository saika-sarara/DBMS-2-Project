/* ==========================================================================
   Learnova Review API (window.LearnovaReviewApi)
   Matches the existing backend review contract:
   - GET  /courses/{courseId}/reviews            (public; optional ?studentId=)
     -> ReviewStateResponse { courseId, avgRating, reviewCount, reviewState,
        canReview, ownReview, reviews[] }
   - POST /student/courses/{courseId}/reviews    (STUDENT; X-Student-Id header)
     -> writes via sp_upsert_review -> sp_create_review (DB enforces the rules)
   ========================================================================== */

window.LearnovaReviewApi = (function () {
    'use strict';

    /* The API client returns the response body; some endpoints wrap it in an
       ApiResponse envelope while others return the DTO directly. Unwrapping is
       defensive and idempotent. */
    function unwrap(promise) {
        return promise.then(function (envelope) {
            return envelope && typeof envelope === 'object' && 'data' in envelope
                ? envelope.data
                : envelope;
        });
    }

    function getState(courseId, studentId) {
        var query = studentId
            ? '?studentId=' + encodeURIComponent(studentId)
            : '';
        return unwrap(LearnovaApiClient.get(
            '/courses/' + encodeURIComponent(courseId) + '/reviews' + query
        ));
    }

    function create(courseId, studentId, review) {
        if (!studentId) {
            return Promise.reject(
                new Error('You must be signed in to review a course.')
            );
        }
        return LearnovaApiClient.request(
            '/student/courses/' + encodeURIComponent(courseId) + '/reviews',
            {
                method: 'POST',
                body: review,
                headers: { 'X-Student-Id': String(studentId) }
            }
        );
    }

    return {
        getState: getState,
        create: create
    };
})();