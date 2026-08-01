/* ==========================================================================
   Instructor Dashboard (dashboard.html)
   Adds a dynamic date to the welcome subtitle.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var today = document.getElementById('todayDate');
    if (!today) return;

    var d = new Date();
    var label = d.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    today.textContent = ' · ' + label;
});
