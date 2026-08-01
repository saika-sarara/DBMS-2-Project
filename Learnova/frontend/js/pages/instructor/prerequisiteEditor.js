/* ==========================================================================
   Instructor Prerequisite Editor (prerequisite-editor.html)
   Add/remove prerequisite courses that gate enrollment for a target course.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var addBtn = document.getElementById('addPrereqBtn');
    if (addBtn) {
        addBtn.addEventListener('click', function () {
            var select = document.getElementById('prereqSelect');
            var name = select.value;
            var list = document.getElementById('prereqList');

            var exists = Array.prototype.some.call(list.querySelectorAll('.prereq-name'), function (el) {
                return el.textContent === name;
            });
            if (exists) {
                alert('That course is already a prerequisite.');
                return;
            }

            var item = document.createElement('div');
            item.className = 'prereq-item';
            item.innerHTML =
                '<span class="prereq-name"></span>' +
                '<span class="prereq-status"><i class="fa-solid fa-check"></i> Completed requirement</span>' +
                '<button class="prereq-remove">&times;</button>';
            item.querySelector('.prereq-name').textContent = name;
            item.querySelector('.prereq-remove').addEventListener('click', function () {
                item.remove();
            });
            list.appendChild(item);
        });
    }

    var saveBtn = document.getElementById('savePrereqBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function () {
            var count = document.querySelectorAll('#prereqList .prereq-item').length;
            alert('Prerequisites saved! ' + count + ' course(s) now gate this course.');
        });
    }
});

/* Remove a prerequisite (called from inline onclick) */
function removePrereq(btn) {
    btn.closest('.prereq-item').remove();
}
