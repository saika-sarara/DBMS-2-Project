/* ==========================================================================
   Student Lesson View (lesson-view.html)
   Renders the lesson content the instructor built in lesson-editor.
   Block types match the database CHECK constraint (LTC13):
   - youtube  : YouTube link -> embedded 16:9 player
   - link     : blog/page link -> link card (opens in a new tab)
   - markdown : markdown text -> rendered nicely (prose styling)
   - pdf      : pdf link -> link card
   Ends with a "Take the Quiz" CTA that leads to the lesson quiz.
   Content + curriculum + pass state all come from the API layer.
   ========================================================================== */
(function () {
    'use strict';

    function el(id) { return document.getElementById(id); }
    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function youtubeId(url) {
        var m = String(url || '').match(
            /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([\w-]{6,})/
        );
        return m ? m[1] : null;
    }

    /* ---------- Tiny markdown renderer ---------- */
    function renderMarkdown(md) {
        if (!md) return '';
        var lines = String(md).replace(/\r\n/g, '\n').split('\n');
        var out = [];
        var inCode = false;
        var codeBuf = [];
        var inList = false;
        var listType = '';

        function closeList() {
            if (inList) {
                out.push('</' + listType + '>');
                inList = false;
            }
        }

        lines.forEach(function (line) {
            var trimmed = line.trim();

            if (trimmed.indexOf('```') === 0) {
                if (inCode) {
                    out.push('<pre><code>' + escapeHtml(codeBuf.join('\n')) + '</code></pre>');
                    codeBuf = [];
                    inCode = false;
                } else {
                    closeList();
                    inCode = true;
                    codeBuf = [];
                }
                return;
            }
            if (inCode) { codeBuf.push(line); return; }

            if (!trimmed) { closeList(); return; }

            var m;

            /* Headings */
            m = trimmed.match(/^(#{1,3})\s+(.*)$/);
            if (m) {
                closeList();
                var level = m[1].length;
                out.push('<h' + level + '>' + inline(m[2]) + '</h' + level + '>');
                return;
            }

            /* Unordered list */
            m = trimmed.match(/^[-*]\s+(.*)$/);
            if (m) {
                if (!inList) { out.push('<ul>'); inList = true; listType = 'ul'; }
                out.push('<li>' + inline(m[1]) + '</li>');
                return;
            }

            /* Ordered list */
            m = trimmed.match(/^\d+\.\s+(.*)$/);
            if (m) {
                if (!inList) { out.push('<ol>'); inList = true; listType = 'ol'; }
                out.push('<li>' + inline(m[1]) + '</li>');
                return;
            }

            closeList();

            /* Blockquote */
            m = trimmed.match(/^>\s?(.*)$/);
            if (m) {
                out.push('<blockquote>' + inline(m[1]) + '</blockquote>');
                return;
            }

            /* Horizontal rule */
            if (/^(-{3,}|\*{3,})$/.test(trimmed)) {
                out.push('<hr>');
                return;
            }

            out.push('<p>' + inline(trimmed) + '</p>');
        });

        if (inCode) {
            out.push('<pre><code>' + escapeHtml(codeBuf.join('\n')) + '</code></pre>');
        }
        closeList();

        return out.join('\n');
    }

    function inline(text) {
        var t = escapeHtml(text);
        t = t.replace(/`([^`]+)`/g, '<code>$1</code>');
        t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        t = t.replace(/__([^_]+)__/g, '<strong>$1</strong>');
        t = t.replace(/\*([^*]+)\*/g, '<em>$1</em>');
        t = t.replace(/([^!])\[([^\]]+)\]\(([^)\s]+)\)/g, '$1<a href="$3" target="_blank" rel="noopener">$2</a>');
        return t;
    }

    /* ---------- Block renderers ---------- */
    function renderBlock(block, index) {
        var type = block.type || 'markdown';
        var label = { youtube: 'Video', link: 'Article', markdown: 'Notes', pdf: 'PDF' }[type] || 'Content';
        var icon = { youtube: 'fa-solid fa-video', link: 'fa-solid fa-newspaper', markdown: 'fa-solid fa-file-lines', pdf: 'fa-solid fa-file-pdf' }[type] || 'fa-solid fa-file';
        var labelHtml = '<div class="block-label"><i class="' + icon + '"></i> ' + label + '</div>';

        if (type === 'youtube') {
            var id = youtubeId(block.url);
            if (id) {
                return '<div class="content-block" style="animation-delay:' + (index * 0.08) + 's">' +
                    labelHtml +
                    '<div class="video-frame">' +
                        '<iframe src="https://www.youtube.com/embed/' + encodeURIComponent(id) +
                            '" title="' + escapeHtml(block.title || 'Lesson video') +
                            '" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>' +
                    '</div>' +
                '</div>';
            }
            return '<div class="content-block" style="animation-delay:' + (index * 0.08) + 's">' +
                labelHtml + linkCard(block) + '</div>';
        }

        if (type === 'link' || type === 'pdf') {
            return '<div class="content-block" style="animation-delay:' + (index * 0.08) + 's">' +
                labelHtml + linkCard(block) + '</div>';
        }

        /* markdown */
        return '<div class="content-block" style="animation-delay:' + (index * 0.08) + 's">' +
            labelHtml +
            '<div class="markdown-body">' + renderMarkdown(block.text || '') + '</div>' +
        '</div>';
    }

    function linkCard(block) {
        var title = block.title || block.url || 'Open resource';
        var isPdf = block.type === 'pdf';
        return '<a class="link-card" href="' + escapeHtml(block.url || '#') + '" target="_blank" rel="noopener">' +
            '<div class="link-card-icon"><i class="' + (isPdf ? 'fa-solid fa-file-pdf' : 'fa-solid fa-arrow-up-right-from-square') + '"></i></div>' +
            '<div>' +
                '<div class="link-card-title">' + escapeHtml(title) + '</div>' +
                '<div class="link-card-url">' + escapeHtml(block.url || '') + '</div>' +
            '</div>' +
            '<span class="btn btn-outline btn-sm link-card-open">Open</span>' +
        '</a>';
    }

    /* ---------- Module rail ---------- */

    function isLessonPassed(course, lessonName) {
        if (course && course.progress && Array.isArray(course.progress.lessons)) {
            for (var i = 0; i < course.progress.lessons.length; i++) {
                if (course.progress.lessons[i].name === lessonName) return !!course.progress.lessons[i].passed;
            }
        }
        return false;
    }

    function renderRail(modules, course, currentLessonName) {
        var rail = el('moduleRail');
        if (!rail) return;

        var header =
            '<div class="rail-header">' +
                '<div class="rail-title">Course Modules</div>' +
                '<div class="rail-header-pct">0%</div>' +
            '</div>' +
            '<div class="rail-progress"><div class="rail-progress-fill"></div></div>';

        if (!modules.length) {
            rail.innerHTML = header + '<p class="empty-note">No modules published yet.</p>';
            return;
        }

        var flat = [];
        modules.forEach(function (m) {
            (m.lessons || []).forEach(function (l) {
                flat.push({ module: m.title, name: l.title, accessStatus: l.accessStatus });
            });
        });

        var currentSlug = slugify(currentLessonName);
        var passedCount = 0;
        var total = flat.length;

        var listHtml = '';
        var currentModuleTitle = '';

        flat.forEach(function (item) {
            var name = item.name;
            var passed = isLessonPassed(course, name);
            var isCurrent = slugify(name) === currentSlug;
            var access = item.accessStatus || 'available';

            /* Lock state comes from the database (syllabus accessStatus);
               the lesson being viewed stays open even if deep-linked. */
            var locked = access === 'locked' && !isCurrent;
            if (passed) passedCount++;

            if (item.module !== currentModuleTitle) {
                if (currentModuleTitle) listHtml += '</div>';
                currentModuleTitle = item.module;
                listHtml += '<div class="rail-module"><div class="rail-module-title">' +
                    escapeHtml(currentModuleTitle) + '</div><div class="rail-lessons">';
            }

            var statusIcon, cls;
            if (passed) {
                statusIcon = '<span class="rail-status done"><i class="fa-solid fa-check"></i></span>';
                cls = 'rail-lesson done';
            } else if (isCurrent) {
                statusIcon = '<span class="rail-status active"><i class="fa-solid fa-play"></i></span>';
                cls = 'rail-lesson active';
            } else if (locked) {
                statusIcon = '<span class="rail-status locked"><i class="fa-solid fa-lock"></i></span>';
                cls = 'rail-lesson locked';
            } else {
                statusIcon = '<span class="rail-status available"><i class="fa-solid fa-circle-play"></i></span>';
                cls = 'rail-lesson available';
            }

            var inner = statusIcon + '<span class="rail-name">' + escapeHtml(name) + '</span>';

            if (locked) {
                listHtml += '<a class="' + cls + '" href="#">' + inner + '</a>';
            } else {
                listHtml += '<a class="' + cls + '" href="lesson-view.html?course=' + encodeURIComponent(courseSlug) +
                    '&lesson=' + encodeURIComponent(name) + '">' + inner + '</a>';
            }
        });
        if (currentModuleTitle) listHtml += '</div></div>';

        rail.innerHTML = header + '<div class="rail-modules">' + listHtml + '</div>';

        var pctEl = rail.querySelector('.rail-header-pct');
        if (pctEl) pctEl.textContent = Math.round((passedCount / total) * 100) + '%';
        var fill = rail.querySelector('.rail-progress-fill');
        if (fill) fill.style.width = Math.round((passedCount / total) * 100) + '%';
    }

    /* ---------- Page setup ---------- */
    var params = new URLSearchParams(window.location.search);
    var courseSlug = params.get('course') || '';
    var lessonName = params.get('lesson') || '';

    /* The backend addresses every course by numeric id. The student views
       may still carry a slug, so resolve it through the catalogue before
       making any call. */
    function resolveCourseId(raw) {
        var trimmed = String(raw || '').trim();
        if (/^\d+$/.test(trimmed)) return Promise.resolve(trimmed);
        return LearnovaCourseApi.list().then(function (cards) {
            for (var i = 0; i < (cards || []).length; i++) {
                if (String(cards[i].slug) === trimmed) {
                    var id = cards[i].id !== undefined && cards[i].id !== null ? cards[i].id : null;
                    return id !== null ? String(id) : '';
                }
            }
            return '';
        }).catch(function () { return ''; });
    }

    function findLessonInSyllabus(syllabus, name) {
        var modules = (syllabus && Array.isArray(syllabus.modules)) ? syllabus.modules : [];
        for (var i = 0; i < modules.length; i++) {
            var lessons = modules[i].lessons || [];
            for (var j = 0; j < lessons.length; j++) {
                if (slugify(lessons[j].title) === slugify(name || '')) return lessons[j];
            }
        }
        return null;
    }

    function emptyContent() {
        return '<div class="empty-state">' +
            '<div class="empty-icon"><i class="fa-solid fa-hammer"></i></div>' +
            '<h3>Lesson content is on its way</h3>' +
            '<p>The instructor hasn\'t added content to this lesson yet. When they publish videos, notes, and links, they will appear here.</p>' +
        '</div>';
    }

    function lockedContent() {
        return '<div class="empty-state">' +
            '<div class="empty-icon"><i class="fa-solid fa-lock"></i></div>' +
            '<h3>This lesson is locked</h3>' +
            '<p>Enroll in the course to unlock this lesson and its quiz.</p>' +
        '</div>';
    }

    function load() {
        resolveCourseId(courseSlug).then(function (id) {
            if (!id) {
                var failBox = el('lessonContent');
                if (failBox) {
                    failBox.innerHTML =
                        '<div class="empty-state">' +
                            '<div class="empty-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>' +
                            '<h3>Could not load this lesson</h3>' +
                            '<p>Open the lesson from the course page.</p>' +
                        '</div>';
                }
                return;
            }
            courseSlug = id;

            var backLink = el('backToCourse');
            if (backLink) backLink.href = 'course-detail.html?course=' + encodeURIComponent(courseSlug);

            var quizBtn = el('takeQuizBtn');
            if (quizBtn) quizBtn.href = 'quiz-attempt.html?course=' + encodeURIComponent(courseSlug) +
                '&lesson=' + encodeURIComponent(lessonName || 'Introduction to Databases');

            if (lessonName) {
                var titleEl = el('lessonTitle');
                if (titleEl) titleEl.textContent = lessonName;
                var kicker = el('lessonKicker');
                if (kicker) kicker.textContent = 'Lesson';
            }

            Promise.all([
                LearnovaCourseApi.get(courseSlug).catch(function () { return null; }),
                LearnovaCourseApi.getSyllabus(courseSlug).catch(function () { return null; })
            ]).then(function (results) {
                var course = results[0];
                var syllabus = results[1];
                var modules = (syllabus && Array.isArray(syllabus.modules)) ? syllabus.modules : [];
                var lesson = findLessonInSyllabus(syllabus, lessonName);

                renderRail(modules, course, lessonName);

                var contentBox = el('lessonContent');
                if (!contentBox) return;

                if (!lesson) {
                    contentBox.innerHTML = emptyContent();
                    return;
                }

                if (lesson.accessStatus === 'locked' && !(course && course.enrolled)) {
                    contentBox.innerHTML = lockedContent();
                    return;
                }

                return LearnovaCourseApi.getLessonContent(lesson.lessonId).then(function (blocks) {
                    var mapped = (blocks || []).map(function (block) {
                        return {
                            type: block.blockType || 'markdown',
                            url: block.resourceUrl || '',
                            title: block.title || '',
                            text: block.bodyMarkdown || ''
                        };
                    });

                    if (!mapped.length) {
                        contentBox.innerHTML = emptyContent();
                        return;
                    }

                    contentBox.innerHTML = mapped.map(renderBlock).join('');
                }).catch(function () {
                    contentBox.innerHTML = lockedContent();
                });
            });
        });
    }

    document.addEventListener('click', function (event) {
        var locked = event.target.closest('.rail-lesson.locked');
        if (locked) {
            event.preventDefault();
            LearnovaToast.info('This lesson is locked. Complete the previous lesson\'s quiz (≥60%) to unlock it.');
        }
    });

    document.addEventListener('DOMContentLoaded', load);
})();
