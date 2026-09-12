(function () {
    'use strict';

    var root = document.getElementById('app-content');
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

    function formatDate(value) {
        var date = new Date(value);
        return Number.isNaN(date.getTime())
            ? 'Unknown issue date'
            : date.toLocaleDateString(undefined, {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
    }

    function renderLoading() {
        root.innerHTML =
            '<h1 class="page-title">My Certificates</h1>' +
            '<p class="subtitle">Loading certificates issued by Learnova.</p>' +
            '<div class="dash-card"><p>Loading...</p></div>';
    }

    function renderError() {
        root.innerHTML =
            '<h1 class="page-title">My Certificates</h1>' +
            '<div class="catalog-state catalog-error">' +
                '<h2>Certificates could not be loaded</h2>' +
                '<p>The live certificate service returned an error.</p>' +
            '</div>';
    }

    function render(certificates) {
        if (!certificates.length) {
            root.innerHTML =
                '<h1 class="page-title">My Certificates</h1>' +
                '<p class="subtitle">Certificates are issued automatically after completion.</p>' +
                '<div class="empty-state"><p>No certificates have been issued yet.</p></div>';
            return;
        }

        root.innerHTML =
            '<h1 class="page-title">My Certificates</h1>' +
            '<p class="subtitle">Certificates issued by the database-backed completion flow.</p>' +
            '<div class="progress-list">' +
                certificates.map(function (certificate) {
                    var code = escapeHtml(certificate.certCode);
                    return '<article class="dash-card certificate-card">' +
                        '<h2>' + escapeHtml(certificate.type) + ' certificate</h2>' +
                        '<p>Certificate code: <strong>' + code + '</strong></p>' +
                        '<p>Issued ' + escapeHtml(formatDate(certificate.issuedAt)) + '</p>' +
                        '<a class="btn btn-outline" href="certificate-verify.html?code=' +
                            encodeURIComponent(certificate.certCode) +
                            '">Verify certificate</a>' +
                    '</article>';
                }).join('') +
            '</div>';
    }

    renderLoading();
    LearnovaCertificateApi.listByUser()
        .then(function (response) {
            var data = response && response.data !== undefined
                ? response.data
                : response;
            render(Array.isArray(data) ? data : []);
        })
        .catch(renderError);
})();
