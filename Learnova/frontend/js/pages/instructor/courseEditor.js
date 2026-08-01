/* ==========================================================================
   Instructor Course Editor (course-editor.html)
   Course settings + curriculum builder. Modules and lessons persist to
   localStorage so the student course detail page can render the curriculum.
   Each lesson links to its own content editor (lesson-editor.html).
   ========================================================================== */
(function () {
    'use strict';

    var COURSES_KEY = window.LearnovaConstants ? LearnovaConstants.COURSES_KEY : 'learnova_courses';

    function slugify(name) {
        return String(name || 'course').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function readCourses() {
        try { return JSON.parse(localStorage.getItem(COURSES_KEY) || '[]'); }
        catch (e) { return []; }
    }

    var params = new URLSearchParams(window.location.search);
    var courseKey = params.get('course') || slugify(document.title.replace(/ - Learnova$/, '')) || 'course';

    var STORE_KEY = 'learnova_curriculum_' + courseKey;

    var state = { modules: [] };

    function load() {
        try {
            var raw = JSON.parse(localStorage.getItem(STORE_KEY) || 'null');
            if (raw && Array.isArray(raw.modules)) state.modules = raw.modules;
        } catch (e) { state.modules = []; }

        var course = readCourses().filter(function (c) { return c.slug === courseKey; })[0];
        if (course) {
            var titleEl = document.getElementById('courseTitle');
            var descEl = document.getElementById('courseDescription');
            var trackEl = document.getElementById('courseTrack');
            if (titleEl) titleEl.value = course.title || '';
            if (descEl) descEl.value = course.description || '';
            if (trackEl && course.track) trackEl.value = course.track;
        }
    }

    function save() {
        localStorage.setItem(STORE_KEY, JSON.stringify({ modules: state.modules }));
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
                        '<a class="quiz-link" href="quiz-editor.html?lesson=' + encodeURIComponent(lesson.name) + '">Quiz (20 MCQ)</a>' +
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
        var name = prompt('Enter module title (e.g. "Module 1: Foundations"):', 'Module ' + (state.modules.length + 1));
        if (name === null || !name.trim()) return;
        state.modules.push({ title: name.trim(), lessons: [] });
        save();
        render();
    }

    function deleteModule(mIndex) {
        if (!confirm('Delete this module and its lessons?')) return;
        state.modules.splice(mIndex, 1);
        save();
        render();
    }

    function addLesson(mIndex) {
        var name = prompt('Enter lesson name:', 'Lesson ' + (state.modules[mIndex].lessons.length + 1));
        if (name === null || !name.trim()) return;
        state.modules[mIndex].lessons.push({ name: name.trim() });
        save();
        render();
    }

    function deleteLesson(mIndex, lIndex) {
        if (!confirm('Delete this lesson?')) return;
        state.modules[mIndex].lessons.splice(lIndex, 1);
        save();
        render();
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
        render();

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
                alert('Please enter a course title before saving.');
                return;
            }
            var course = {
                slug: slugify(title),
                title: title,
                description: document.getElementById('courseDescription').value.trim(),
                track: document.getElementById('courseTrack').value,
                status: 'draft',
                instructorEmail: (LearnovaSession && LearnovaSession.currentUser()) ? (LearnovaSession.currentUser().email || '') : ''
            };
            var courses = readCourses().filter(function (c) { return c.slug !== course.slug; });
            courses.unshift(course);
            localStorage.setItem(COURSES_KEY, JSON.stringify(courses));

            var curriculumKey = 'learnova_curriculum_' + course.slug;
            if (curriculumKey !== STORE_KEY) {
                localStorage.setItem(curriculumKey, JSON.stringify({ modules: state.modules }));
            }

            toast('Course settings saved. ' + state.modules.length + ' module(s) in the curriculum.');
        });
    });
})();
