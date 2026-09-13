(function () {
    'use strict';

    var root = document.getElementById('track-content');
    if (!root) {
        return;
    }

    function escapeHtml(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    LearnovaTrackApi.list()
        .then(function (response) {
            var tracks = response && response.data !== undefined
                ? response.data
                : response;
            if (!Array.isArray(tracks) || !tracks.length) {
                root.innerHTML = '<h1>Learning Tracks</h1><p>No published tracks are available.</p>';
                return;
            }
            root.innerHTML = '<h1>Learning Tracks</h1>' + tracks.map(function (track) {
                return '<article class="dash-card">' +
                    '<h2>' + escapeHtml(track.title) + '</h2>' +
                    '<p>' + escapeHtml(track.description || '') + '</p>' +
                    '<button type="button" class="track-enroll" data-track-id="' +
                    escapeHtml(track.id) + '">Enroll in track</button>' +
                    '<ol>' + (track.courses || []).map(function (course) {
                        return '<li><a href="course-detail.html?course=' +
                            encodeURIComponent(course.courseId) + '">' +
                            escapeHtml(course.title) + '</a></li>';
                    }).join('') + '</ol>' +
                '</article>';
            }).join('');
            Array.prototype.forEach.call(root.querySelectorAll('.track-enroll'), function (button) {
                button.addEventListener('click', function () {
                    if (!LearnovaSession.currentUser()) {
                        window.location.href = '../auth/login.html';
                        return;
                    }
                    button.disabled = true;
                    LearnovaEnrollmentApi.enrollTrack(button.dataset.trackId)
                        .then(function () {
                            button.textContent = 'Enrolled';
                        })
                        .catch(function (error) {
                            button.disabled = false;
                            button.textContent = error.message || 'Enrollment failed';
                        });
                });
            });
        })
        .catch(function () {
            root.innerHTML = '<h1>Learning Tracks</h1><p>The live track service returned an error.</p>';
        });
})();
