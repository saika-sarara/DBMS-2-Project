/* ==========================================================================
   Instructor Course Editor (course-editor.html)
   Course settings + curriculum builder. Modules and lessons persist through
   LearnovaCourseApi so the student course detail page can render the
   curriculum. Each lesson links to its own content editor (lesson-editor.html).
   ========================================================================== */
(function () {
    'use strict';

    function slugify(name) {
        return String(name || 'course').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    var params = new URLSearchParams(window.location.search);
    var courseKey = params.get('course') || slugify(document.title.replace(/ - Learnova$/, '')) || 'course';

    var state = { modules: [] };

    function load() {
        LearnovaCourseApi.getCurriculum(courseKey).then(function (curriculum) {
            state.modules = (curriculum && Array.isArray(curriculum.modules)) ? curriculum.modules : [];
            render();
        }).catch(function () {
            state.modules = [];
            render();
        });

        LearnovaCourseApi.get(courseKey).then(function (course) {
            var titleEl = document.getElementById('courseTitle');
            var descEl = document.getElementById('courseDescription');
            var trackEl = document.getElementById('courseTrack');
            if (titleEl) titleEl.value = course.title || '';
            if (descEl) descEl.value = course.description || '';
            if (trackEl && course.track) trackEl.value = course.track;
        }).catch(function () { /* brand-new course: leave fields blank */ });
    }

    function save() {
        return LearnovaCourseApi.setCurriculum(courseKey, { modules: state.modules });
    }

    function render() {
        var container = document.getElementById('curriculum');
        if (!container) return;

        if (state.modules.length === 0) {
            container.innerHTML =
                '<div class="blocks-empty">' +
                    'No modules yet. Add your first module and start building lessons.' +
                '</div>';
            return;
        }

        container.innerHTML = state.modules.map(function (module, mIndex) {
            var lessons = module.lessons.map(function (lesson) {
                var slug = slugify(lesson.name);
                return '<div class="lesson-block">' +
                    '<span class="lesson-name">' + escapeHtml(lesson.name) + '</span>' +
                    '<div class="lesson-actions">' +
                        '<a class="quiz-link" href="lesson-editor.html?course=' + encodeURIComponent(courseKey) +
                            '&lesson=' + encodeURIComponent(lesson.name) + '">Edit Content</a>' +
                        '<a class="quiz-link" href="quiz-editor.html?course=' + encodeURIComponent(courseKey) +
                            '&lesson=' + encodeURIComponent(lesson.name) + '">Quiz (20 MCQ)</a>' +
                        '<button class="btn btn-danger btn-sm" data-action="delete-lesson" data-m="' + mIndex + '" data-l="' +
                            state.modules[mIndex].lessons.indexOf(lesson) + '"><i class="fa-solid fa-trash"></i></button>' +
                    '</div>' +
                '</div>';
            }).join('');

            return '<div class="module-block" data-module="' + (mIndex + 1) + '">' +
                '<div class="module-head">' +
                    '<span class="module-title">' + escapeHtml(module.title || ('Module ' + (mIndex + 1))) + '</span>' +
                    '<div class="lesson-actions">' +
                        '<button class="btn btn-danger btn-sm" data-action="delete-module" data-m="' + mIndex + '">Delete Module</button>' +
                    '</div>' +
                '</div>' +
                '<div class="module-lessons">' + (lessons || '<span class="meta-item">No lessons yet.</span>') + '</div>' +
                '<button class="btn-add-sm" style="margin-top: 1rem;" data-action="add-lesson" data-m="' + mIndex + '">+ Add Lesson to this Module</button>' +
            '</div>';
        }).join('');
    }

    function escapeHtml(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function addModule() {
        return LearnovaPrompt.ask('Enter module title (e.g. "Module 1: Foundations"):', {
            title: 'New Module',
            defaultValue: 'Module ' + (state.modules.length + 1)
        }).then(function (name) {
            if (!name || !name.trim()) return;
            state.modules.push({ title: name.trim(), lessons: [] });
            save();
            render();
        });
    }

    function deleteModule(mIndex) {
        return LearnovaConfirm.ask('Delete this module and its lessons?').then(function (ok) {
            if (!ok) return;
            state.modules.splice(mIndex, 1);
            save();
            render();
        });
    }

    function addLesson(mIndex) {
        return LearnovaPrompt.ask('Enter lesson name:', {
            title: 'New Lesson',
            defaultValue: 'Lesson ' + (state.modules[mIndex].lessons.length + 1)
        }).then(function (name) {
            if (!name || !name.trim()) return;
            state.modules[mIndex].lessons.push({ name: name.trim() });
            save();
            render();
        });
    }

    function deleteLesson(mIndex, lIndex) {
        return LearnovaConfirm.ask('Delete this lesson?').then(function (ok) {
            if (!ok) return;
            state.modules[mIndex].lessons.splice(lIndex, 1);
            save();
            render();
        });
    }

    function toast(message) {
        var note = document.createElement('div');
        note.className = 'course-toast';
        note.textContent = message;
        document.body.appendChild(note);
        setTimeout(function () { if (note.parentNode) note.parentNode.removeChild(note); }, 2600);
    }

    document.addEventListener('DOMContentLoaded', function () {
        load();

        document.getElementById('addModuleBtn').addEventListener('click', addModule);

        document.getElementById('curriculum').addEventListener('click', function (event) {
            var btn = event.target.closest('[data-action]');
            if (!btn) return;
            var action = btn.getAttribute('data-action');
            var m = Number(btn.getAttribute('data-m'));
            if (action === 'add-lesson') addLesson(m);
            else if (action === 'delete-module') deleteModule(m);
            else if (action === 'delete-lesson') deleteLesson(m, Number(btn.getAttribute('data-l')));
        });

        document.getElementById('saveSettingsBtn').addEventListener('click', function () {
            var title = document.getElementById('courseTitle').value.trim();
            if (!title) {
                LearnovaToast.error('Please enter a course title before saving.');
                return;
            }
            LearnovaCourseApi.update(courseKey, {
                title: title,
                description: document.getElementById('courseDescription').value.trim(),
                track: document.getElementById('courseTrack').value
            }).then(function (course) {
                var newKey = course.slug;
                if (newKey && newKey !== courseKey) {
                    LearnovaCourseApi.setCurriculum(newKey, { modules: state.modules });
                }
                toast('Course settings saved. ' + state.modules.length + ' module(s) in the curriculum.');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not save course settings.');
            });
        });
    });
})();
