/* ==========================================================================
   Instructor Course Editor (course-editor.html)
   Course settings + curriculum builder, fully driven by
   LearnovaInstructorApi against the backend:
   - the page is opened with ?course=<numeric id> (the courses page links
     by courseId; the backend is id-based, not slug-based)
   - basic settings (title, category, difficulty, description) are saved via
     PUT /instructor/courses/{courseId}
   - modules + lessons are loaded from and saved to the backend as one
     atomic curriculum replace (sp_replace_course_curriculum)
   Each lesson links to its own content editor (lesson-editor.html) and
   quiz editor (quiz-editor.html).
   ========================================================================== */
(function () {
    'use strict';

    var params = new URLSearchParams(window.location.search);
    var courseParam = params.get('course');
    var courseId = /^\d+$/.test(String(courseParam || '').trim())
        ? String(courseParam).trim()
        : null;

    var state = { modules: [], thumbnailUrl: null, shortDescription: '' };

    if (!courseId) {
        /* Legacy slug links cannot be resolved against the id-based backend.
           The courses page links by numeric id, so bounce back to it. */
        window.location.replace('courses.html');
    }

    function toBackendCurriculum() {
        return {
            modules: state.modules.map(function (module) {
                return {
                    title: module.title,
                    description: module.description || null,
                    lessons: (module.lessons || []).map(function (lesson) {
                        return { title: lesson.name };
                    })
                };
            })
        };
    }

    function loadCurriculum() {
        LearnovaInstructorApi.getCurriculum(courseId).then(function (curriculum) {
            state.modules = ((curriculum && curriculum.modules) || []).map(function (module) {
                return {
                    moduleId: module.moduleId,
                    title: module.title,
                    lessons: (module.lessons || []).map(function (lesson) {
                        return { lessonId: lesson.lessonId, name: lesson.title };
                    })
                };
            });
            render();
        }).catch(function () {
            state.modules = [];
            render();
        });
    }

    function populateSettings(course) {
        var titleEl = document.getElementById('courseTitle');
        var descEl = document.getElementById('courseDescription');
        if (titleEl) titleEl.value = course.title || '';
        if (descEl) descEl.value = course.description || course.shortDescription || '';
        state.shortDescription = course.shortDescription || course.description || '';
        state.thumbnailUrl = course.thumbnailUrl || null;

        var categoryEl = document.getElementById('courseCategory');
        if (categoryEl && course.categoryId) categoryEl.value = String(course.categoryId);

        var difficultyEl = document.getElementById('courseDifficulty');
        if (difficultyEl && course.difficulty) difficultyEl.value = course.difficulty;
    }

    function loadSettings() {
        return LearnovaInstructorApi.getCourse(courseId).then(populateSettings)
            .catch(function () { /* brand-new course: leave fields blank */ });
    }

    function loadCategories() {
        return LearnovaCourseApi.getCatalogueCategories().then(function (categories) {
            var select = document.getElementById('courseCategory');
            if (!select) return;
            var options = '<option value="">No category</option>';
            options += (categories || []).map(function (category) {
                return '<option value="' + category.id + '">' +
                    escapeHtml(category.name) + '</option>';
            }).join('');
            select.innerHTML = options;
        }).catch(function () { /* category select stays empty */ });
    }

    function save() {
        return LearnovaInstructorApi.setCurriculum(courseId, toBackendCurriculum());
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
            var lessons = (module.lessons || []).map(function (lesson, lIndex) {
                var nameKey = encodeURIComponent(lesson.name);
                return '<div class="lesson-block">' +
                    '<span class="lesson-name">' + escapeHtml(lesson.name) + '</span>' +
                    '<div class="lesson-actions">' +
                        '<a class="quiz-link" href="lesson-editor.html?course=' + encodeURIComponent(courseId) +
                            '&lesson=' + nameKey + '">Edit Content</a>' +
                        '<a class="quiz-link" href="quiz-editor.html?course=' + encodeURIComponent(courseId) +
                            '&lesson=' + nameKey + '">Quiz (20 MCQ)</a>' +
                        '<button class="btn btn-danger btn-sm" data-action="delete-lesson" data-m="' + mIndex + '" data-l="' +
                            lIndex + '"><i class="fa-solid fa-trash"></i></button>' +
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
            save().then(render).catch(function (err) {
                state.modules.pop();
                toast((err && err.message) || 'Could not save module.');
            });
        });
    }

    function deleteModule(mIndex) {
        return LearnovaConfirm.ask('Delete this module and its lessons?').then(function (ok) {
            if (!ok) return;
            var removed = state.modules.splice(mIndex, 1);
            save().then(render).catch(function (err) {
                state.modules.splice(mIndex, 0, removed[0]);
                toast((err && err.message) || 'Could not delete module.');
            });
        });
    }

    function addLesson(mIndex) {
        return LearnovaPrompt.ask('Enter lesson name:', {
            title: 'New Lesson',
            defaultValue: 'Lesson ' + (state.modules[mIndex].lessons.length + 1)
        }).then(function (name) {
            if (!name || !name.trim()) return;
            state.modules[mIndex].lessons.push({ name: name.trim() });
            save().then(render).catch(function (err) {
                state.modules[mIndex].lessons.pop();
                toast((err && err.message) || 'Could not save lesson.');
            });
        });
    }

    function deleteLesson(mIndex, lIndex) {
        return LearnovaConfirm.ask('Delete this lesson?').then(function (ok) {
            if (!ok) return;
            var removed = state.modules[mIndex].lessons.splice(lIndex, 1);
            save().then(render).catch(function (err) {
                state.modules[mIndex].lessons.splice(lIndex, 0, removed[0]);
                toast((err && err.message) || 'Could not delete lesson.');
            });
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
        if (!courseId) return;

        loadCategories();
        loadCurriculum();
        loadSettings();

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

            var categoryEl = document.getElementById('courseCategory');
            var difficultyEl = document.getElementById('courseDifficulty');
            var description = document.getElementById('courseDescription').value.trim();
            var categoryId = Number(categoryEl && categoryEl.value) || null;

            if (!categoryId) {
                LearnovaToast.error('Please choose a category before saving.');
                return;
            }

            LearnovaInstructorApi.updateCourse(courseId, {
                categoryId: categoryId,
                title: title,
                shortDescription: state.shortDescription || description,
                description: description,
                difficulty: (difficultyEl && difficultyEl.value) || 'beginner',
                thumbnailUrl: state.thumbnailUrl
            }).then(function (course) {
                state.shortDescription = (course && course.shortDescription) || state.shortDescription;
                toast('Course settings saved. ' + state.modules.length + ' module(s) in the curriculum.');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not save course settings.');
            });
        });
    });
})();
