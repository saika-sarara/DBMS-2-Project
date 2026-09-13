(function () {
    'use strict';
    var root = document.getElementById('track-content');
    if (!root) { return; }
    function escapeHtml(value) { return String(value == null ? '' : value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;'); }
    function enrolledIds(items) { return (Array.isArray(items) ? items : []).reduce(function (ids, item) { if (item && item.entityId != null) { ids[String(item.entityId)] = true; } return ids; }, {}); }
    function courseList(track) {
        var courses = Array.isArray(track.courses) ? track.courses.slice() : [];
        courses.sort(function (a, b) { return (a.sequenceOrder || 0) - (b.sequenceOrder || 0); });
        if (!courses.length) { return '<p class="track-empty-course">Course sequence coming soon.</p>'; }
        return '<ol class="track-course-list">' + courses.map(function (course, index) {
            var order = course.sequenceOrder || index + 1;
            return '<li class="track-course-item"><span class="track-course-order">' + escapeHtml(order) + '</span><div><a href="course-detail.html?course=' + encodeURIComponent(course.courseId) + '">' + escapeHtml(course.title || 'Untitled course') + '</a>' + (course.description ? '<p>' + escapeHtml(course.description) + '</p>' : '') + '</div></li>';
        }).join('') + '</ol>';
    }
    function bindEnrollment() {
        Array.prototype.forEach.call(root.querySelectorAll('.track-enroll:not(.is-enrolled)'), function (button) {
            button.addEventListener('click', function () {
                button.disabled = true;
                button.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Enrolling...';
                LearnovaEnrollmentApi.enrollTrack(button.dataset.trackId).then(function () {
                    button.classList.add('is-enrolled'); button.innerHTML = '<i class="fa-solid fa-check"></i> Enrolled';
                }).catch(function (error) { button.disabled = false; button.textContent = (error && error.message) || 'Enrollment failed — try again'; });
            });
        });
    }
    function render(tracks, joined) {
        var count = tracks.length;
        root.innerHTML = '<section class="tracks-hero"><div><p class="tracks-kicker">Curated learning journeys</p><h1>Find your next learning path</h1><p>Follow a thoughtfully ordered series of courses and build practical skills with confidence.</p></div><div class="tracks-summary"><strong>' + count + '</strong><span>published ' + (count === 1 ? 'track' : 'tracks') + '</span></div></section><section class="tracks-grid" aria-label="Published learning tracks">' + tracks.map(function (track) {
            var isJoined = joined[String(track.id)], courses = Array.isArray(track.courses) ? track.courses : [];
            return '<article class="track-card"><div class="track-card-top"><span class="track-icon"><i class="fa-solid fa-route"></i></span>' + (isJoined ? '<span class="track-status"><i class="fa-solid fa-check"></i> Enrolled</span>' : '') + '</div><h2>' + escapeHtml(track.title) + '</h2><p class="track-description">' + escapeHtml(track.description || 'A structured path to help you build skills step by step.') + '</p><div class="track-meta"><i class="fa-solid fa-layer-group"></i> ' + courses.length + ' ' + (courses.length === 1 ? 'course' : 'courses') + '</div><div class="track-sequence"><h3>Course sequence</h3>' + courseList(track) + '</div><button type="button" class="track-enroll ' + (isJoined ? 'is-enrolled' : '') + '" data-track-id="' + escapeHtml(track.id) + '"' + (isJoined ? ' disabled' : '') + '>' + (isJoined ? '<i class="fa-solid fa-check"></i> Enrolled' : 'Enroll in track <i class="fa-solid fa-arrow-right"></i>') + '</button></article>';
        }).join('') + '</section>';
        bindEnrollment();
    }
    root.innerHTML = '<div class="tracks-loading"><i class="fa-solid fa-spinner fa-spin"></i><p>Loading learning tracks...</p></div>';
    Promise.all([LearnovaTrackApi.list(), LearnovaEnrollmentApi.myTracks().catch(function () { return []; })]).then(function (results) {
        var response = results[0], tracks = response && response.data !== undefined ? response.data : response;
        if (!Array.isArray(tracks) || !tracks.length) { root.innerHTML = '<section class="empty-state"><div class="empty-icon"><i class="fa-solid fa-route"></i></div><h3>No tracks available yet</h3><p>Published learning paths will appear here as soon as they are ready.</p><a class="dash-outline-btn" href="catalog.html">Explore the catalog</a></section>'; return; }
        render(tracks, enrolledIds(results[1]));
    }).catch(function () { root.innerHTML = '<section class="empty-state"><div class="empty-icon"><i class="fa-solid fa-triangle-exclamation"></i></div><h3>Tracks could not load</h3><p>Please refresh the page or try again in a moment.</p></section>'; });
}());
