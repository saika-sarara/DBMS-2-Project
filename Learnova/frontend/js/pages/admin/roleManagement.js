(function () {
    'use strict';

    var grid = document.getElementById('role-grid');
    if (!grid) return;

    function escapeHtml(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    LearnovaApiClient.get('/admin/roles/metadata')
        .then(function (envelope) {
            var roles = envelope && Array.isArray(envelope.data)
                ? envelope.data
                : envelope;
            if (!Array.isArray(roles) || !roles.length) {
                throw new Error('No role metadata returned');
            }
            grid.innerHTML = roles.map(function (role) {
                return '<article class="role-card">' +
                    '<div class="role-card-head">' +
                    '<span class="role-card-title">' + escapeHtml(role.name) + '</span>' +
                    '<span class="role-user-count">' + escapeHtml(role.userCount) + ' users</span>' +
                    '</div>' +
                    '<p class="role-description">' +
                    escapeHtml(role.description || 'Managed by the database role catalogue.') +
                    '</p>' +
                    '</article>';
            }).join('');
        })
        .catch(function (error) {
            grid.innerHTML = '<p role="alert">Unable to load role metadata: ' +
                escapeHtml(error.message) + '</p>';
        });
})();
