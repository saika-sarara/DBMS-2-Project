/* ==========================================================================
   Instructor Prerequisite Editor (prerequisite-editor.html)
   Add/remove prerequisite courses that gate enrollment for a target course.
   Data-driven through LearnovaPrerequisiteApi + LearnovaCourseApi.
   ========================================================================== */

(function () {
    'use strict';

    var params = new URLSearchParams(window.location.search);
    var targetSlug = params.get('course') || '';
    var targetName = '';

    var current = [];          /* { slug, title } saved/loaded prerequisites */
    var listEl = document.getElementById('prereqList');
    var selectEl = document.getElementById('prereqSelect');
    var targetEl = document.getElementById('targetCourse');

    function toast(message) {
        var note = document.createElement('div');
        note.className = 'course-toast';
        note.textContent = message;
        document.body.appendChild(note);
        setTimeout(function () { if (note.parentNode) note.parentNode.removeChild(note); }, 2600);
    }

    function renderList() {
        if (!listEl) return;
        listEl.innerHTML = '';
        if (!current.length) {
            listEl.innerHTML = '<div class="blocks-empty">No prerequisites yet. Add courses students must finish first.</div>';
            return;
        }
        current.forEach(function (item) {
            var row = document.createElement('div');
            row.className = 'prereq-item';
            row.innerHTML =
                '<span class="prereq-name"></span>' +
                '<span class="prereq-status"><i class="fa-solid fa-check"></i> Required</span>' +
                '<button class="prereq-remove" type="button">&times;</button>';
            row.querySelector('.prereq-name').textContent = item.title;
            row.querySelector('.prereq-remove').addEventListener('click', function () {
                current = current.filter(function (c) { return c.slug !== item.slug; });
                renderList();
            });
            listEl.appendChild(row);
        });
    }

    function populateAddSelect(courses) {
        if (!selectEl) return;
        var options = courses
            .filter(function (c) { return c.slug !== targetSlug; })
            .map(function (c) {
                return '<option value="' + escapeAttr(c.slug) + '">' + escapeHtml(c.title) + '</option>';
            })
            .join('');
        selectEl.innerHTML = options || '<option value="">No other courses available</option>';
    }

    function populateTarget(courses) {
        if (!targetEl) return;
        var selected = targetSlug;
        var options = courses.map(function (c) {
            var sel = c.slug === selected ? ' selected' : '';
            return '<option value="' + escapeAttr(c.slug) + '"' + sel + '>' + escapeHtml(c.title) + '</option>';
        }).join('');
        targetEl.innerHTML = options || '<option value="">No courses available</option>';
    }

    function escapeHtml(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function escapeAttr(text) {
        return escapeHtml(text).replace(/'/g, '&#39;');
    }

    function load() {
        LearnovaCourseApi.list().then(function (courses) {
            if (!targetSlug) {
                targetSlug = courses.length ? courses[0].slug : '';
            }
            populateTarget(courses);
            populateAddSelect(courses);
            return LearnovaPrerequisiteApi.listForCourse(targetSlug).then(function (prereqs) {
                current = (prereqs || []).map(function (p) { return { slug: p.slug, title: p.title }; });
                renderList();
            });
        }).catch(function (err) {
            toast((err && err.message) || 'Could not load courses.');
        });
    }

    var addBtn = document.getElementById('addPrereqBtn');
    if (addBtn) {
        addBtn.addEventListener('click', function () {
            if (!selectEl || !selectEl.value) return;
            var slug = selectEl.value;
            var title = selectEl.options[selectEl.selectedIndex].text;
            if (slug === targetSlug) {
                alert('A course cannot be its own prerequisite.');
                return;
            }
            if (current.some(function (c) { return c.slug === slug; })) {
                alert('That course is already a prerequisite.');
                return;
            }
            current.push({ slug: slug, title: title });
            renderList();
        });
    }

    var saveBtn = document.getElementById('savePrereqBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function () {
            if (!targetSlug) {
                alert('Choose a target course first.');
                return;
            }
            LearnovaPrerequisiteApi.setPrerequisites(targetSlug, current.map(function (c) { return c.slug; })).then(function () {
                toast('Prerequisites saved! ' + current.length + ' course(s) now gate this course.');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not save prerequisites.');
            });
        });
    }

    if (targetEl) {
        targetEl.addEventListener('change', function () {
            targetSlug = targetEl.value;
            current = [];
            renderList();
            LearnovaPrerequisiteApi.listForCourse(targetSlug).then(function (prereqs) {
                current = (prereqs || []).map(function (p) { return { slug: p.slug, title: p.title }; });
                renderList();
            }).catch(function () { /* ignore */ });
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        load();
    });
})();
