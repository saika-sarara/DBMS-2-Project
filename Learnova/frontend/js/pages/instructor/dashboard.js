/* ==========================================================================
   Instructor Dashboard (dashboard.html)
   Adds a dynamic date to the welcome subtitle and renders the four stat
   cards from the instructor's real course list (LearnovaInstructorApi).
   The counts are pure sums of backend data: active courses, total modules,
   total lessons, and published courses. No business rules live here.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var today = document.getElementById('todayDate');
    if (today) {
        var d = new Date();
        var label = d.toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
        today.textContent = ' · ' + label;
    }

    if (!window.LearnovaInstructorApi ||
        typeof LearnovaInstructorApi.listCourses !== 'function') {
        return;
    }

    function setStat(id, value) {
        var el = document.getElementById(id);
        if (el) el.textContent = String(value);
    }

    LearnovaInstructorApi.listCourses().then(function (courses) {
        courses = courses || [];

        var active = 0;
        var modules = 0;
        var lessons = 0;
        var published = 0;

        courses.forEach(function (course) {
            if (course && course.status !== LearnovaConstants.COURSE_STATUS.ARCHIVED) {
                active += 1;
            }
            if (course) {
                modules += Number(course.moduleCount) || 0;
                lessons += Number(course.lessonCount) || 0;
                if (course.status === LearnovaConstants.COURSE_STATUS.PUBLISHED) {
                    published += 1;
                }
            }
        });

        setStat('statCourses', active);
        setStat('statModules', modules);
        setStat('statLessons', lessons);
        setStat('statPublished', published);
    }).catch(function () {
        setStat('statCourses', '—');
        setStat('statModules', '—');
        setStat('statLessons', '—');
        setStat('statPublished', '—');
    });
});
