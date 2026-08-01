/* ==========================================================================
   Instructor Course Editor (course-editor.html)
   Curriculum builder: add/delete modules, add lessons, save course settings.
   ========================================================================== */

var moduleCounter = 2;

/* Add a brand new module at the end of the curriculum */
function addModule() {
    moduleCounter += 1;
    var curriculum = document.getElementById('curriculum');
    if (!curriculum) return;

    var block = document.createElement('div');
    block.className = 'module-block';
    block.dataset.module = moduleCounter;
    block.innerHTML =
        '<div class="module-head">' +
            '<span class="module-title">Module ' + moduleCounter + ': New Module</span>' +
            '<button class="btn btn-danger btn-sm">Delete</button>' +
        '</div>' +
        '<div class="module-lessons"></div>' +
        '<button class="btn-add-sm" style="margin-top: 1rem;">+ Add Lesson to this Module</button>';

    block.querySelector('.btn-danger').addEventListener('click', function () {
        if (confirm('Delete this module?')) { block.remove(); }
    });
    block.querySelector('.btn-add-sm').addEventListener('click', function () {
        addLesson(block.querySelector('.btn-add-sm'));
    });

    curriculum.appendChild(block);
}

/* Add a lesson row inside a module */
function addLesson(addBtn) {
    var moduleBlock = addBtn.closest('.module-block');
    var lessonsBox = moduleBlock.querySelector('.module-lessons');
    var lessonIndex = lessonsBox.children.length + 1;

    var lessonName = prompt('Enter lesson name:', 'Lesson ' + lessonIndex);
    if (lessonName === null || lessonName.trim() === '') { return; }
    lessonName = lessonName.trim();

    var row = document.createElement('div');
    row.className = 'lesson-block';
    row.innerHTML =
        '<span class="lesson-name"></span>' +
        '<div class="lesson-actions">' +
            '<a class="quiz-link" target="_blank">Manage Quiz (20 MCQ)</a>' +
        '</div>';
    row.querySelector('.lesson-name').textContent = lessonName;
    row.querySelector('.quiz-link').href = 'quiz-editor.html?lesson=' + encodeURIComponent(lessonName);

    lessonsBox.appendChild(row);
}

/* Remove a module from the curriculum */
function deleteModule(btn) {
    if (confirm('Delete this module?')) {
        btn.closest('.module-block').remove();
    }
}

document.addEventListener('DOMContentLoaded', function () {
    var saveBtn = document.getElementById('saveSettingsBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function () {
            alert('Course settings saved successfully!');
        });
    }
});
