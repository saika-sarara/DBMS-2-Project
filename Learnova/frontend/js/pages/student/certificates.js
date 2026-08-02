/* ==========================================================================
   Student Certificates Page
   Renders mock earned certificates into #app-content (or #certificatesGrid).
   Uses white card styling (.dash-card / .card) consistent with the suite.
   ========================================================================== */
(function () {
    'use strict';

    var appContent = document.getElementById('app-content');
    var certGrid = document.getElementById('certificatesGrid');
    var target = appContent || certGrid;
    if (!target) return;

    /* ---------- Mock Certificate Data ---------- */
    var certificates = [
        {
            course: 'SQL Fundamentals',
            date: 'Earned June 2025',
            icon: 'fa-solid fa-database'
        },
        {
            course: 'Introduction to Databases',
            date: 'Earned March 2025',
            icon: 'fa-solid fa-server'
        },
        {
            course: 'Advanced SQL & Optimization',
            date: 'Earned January 2025',
            icon: 'fa-solid fa-code'
        }
    ];

    /* ---------- Template Helpers ---------- */
    function certificateCardHtml(cert) {
        return '<div class="card certificate-card">' +
            '<div class="certificate-icon"><i class="' + cert.icon + '"></i></div>' +
            '<div class="certificate-body">' +
                '<div class="certificate-kicker">Certificate of Completion</div>' +
                '<div class="certificate-title">' + cert.course + '</div>' +
                '<div class="certificate-date">' + cert.date + '</div>' +
            '</div>' +
            '<div class="certificate-actions">' +
                '<button class="btn-outline">View</button>' +
                '<button class="btn-outline"><i class="fa-solid fa-download"></i> Download</button>' +
            '</div>' +
        '</div>';
    }

    function emptyStateHtml() {
        return '<div class="dash-card certificate-empty">' +
            '<div class="certificate-icon"><i class="fa-solid fa-award"></i></div>' +
            '<div class="certificate-body">' +
                '<div class="certificate-title">No certificates yet</div>' +
                '<div class="certificate-date">Complete a course to earn your first certificate.</div>' +
            '</div>' +
        '</div>';
    }

    /* ---------- Render ---------- */
    function renderCertificates() {
        var html = '<h1 class="page-title">My Certificates</h1>' +
            '<p class="subtitle">View and download your earned credentials.</p>';

        if (certificates.length === 0) {
            html += emptyStateHtml();
        } else {
            var cards = certificates.map(certificateCardHtml).join('');
            html += '<div class="certificates-list">' + cards + '</div>';
        }

        target.innerHTML = html;
    }

    renderCertificates();
})();
