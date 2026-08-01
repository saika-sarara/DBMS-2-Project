/* ==========================================================================
   Instructor Lesson Editor (lesson-editor.html)
   Save the lesson content (simulated).
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var saveBtn = document.getElementById('saveLessonBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function () {
            alert('Lesson content saved successfully!');
        });
    }
});
