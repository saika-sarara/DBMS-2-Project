/* ==========================================================================
   Learnova Review API (window.LearnovaReviewApi)
   Matches the existing backend review contract:
   - GET  /courses/{courseId}/reviews            (public; student resolved from JWT)
     -> ReviewStateResponse { courseId, avgRating, reviewCount, reviewState,
        canReview, ownReview, reviews[] }
   - POST /student/courses/{courseId}/reviews    (STUDENT; actor from JWT only)
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

    function getState(courseId) {
        return unwrap(LearnovaApiClient.get(
            '/courses/' + encodeURIComponent(courseId) + '/reviews'
        ));
    }

    function create(courseId, review) {
        return LearnovaApiClient.request(
            '/student/courses/' + encodeURIComponent(courseId) + '/reviews',
            {
                method: 'POST',
                body: review
            }
        );
    }

    return {
        getState: getState,
        create: create
    };
})();