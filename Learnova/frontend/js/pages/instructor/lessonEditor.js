/* ==========================================================================
   Instructor Lesson Editor (lesson-editor.html)
   Builds a lesson from content blocks: youtube (YouTube), link
   (blog/article link), markdown (notes), and pdf link. Block type values
   match the database CHECK constraint (LTC13). YouTube URLs get a live
   embed preview.
   Persists through the live backend: the lesson is located in the course
   curriculum (numeric lesson id), its blocks are read from the instructor
   lesson-content endpoint (ownership-gated), and saved with the instructor
   granular CRUD (create / update / delete content blocks).
   ========================================================================== */
(function () {
    'use strict';

    function slugify(name) {
        return String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }

    var BLOCK_TYPES = [
        { value: 'youtube', label: 'Video (YouTube)' },
        { value: 'link', label: 'Blog / Article Link' },
        { value: 'markdown', label: 'Notes (Markdown)' },
        { value: 'pdf', label: 'PDF Link' }
    ];

    function youtubeId(url) {
        var m = String(url || '').match(
            /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([\w-]{6,})/
        );
        return m ? m[1] : null;
    }

    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function renderMarkdown(md) {
        if (!md) return '<p style="color:#9aa0c4;">Nothing written yet — start typing in markdown.</p>';
        var lines = String(md).replace(/\r\n/g, '\n').split('\n');
        var out = [], inCode = false, codeBuf = [], inList = false, listType = '';

        function closeList() { if (inList) { out.push('</' + listType + '>'); inList = false; } }

        lines.forEach(function (line) {
            var trimmed = line.trim();
            if (trimmed.indexOf('```') === 0) {
                if (inCode) { out.push('<pre><code>' + escapeHtml(codeBuf.join('\n')) + '</code></pre>'); codeBuf = []; inCode = false; }
                else { closeList(); inCode = true; codeBuf = []; }
                return;
            }
            if (inCode) { codeBuf.push(line); return; }
            if (!trimmed) { closeList(); return; }

            var m = trimmed.match(/^(#{1,3})\s+(.*)$/);
            if (m) { closeList(); out.push('<h' + m[1].length + '>' + inline(m[2]) + '</h' + m[1].length + '>'); return; }

            m = trimmed.match(/^[-*]\s+(.*)$/);
            if (m) { if (!inList) { out.push('<ul>'); inList = true; listType = 'ul'; } out.push('<li>' + inline(m[1]) + '</li>'); return; }

            m = trimmed.match(/^\d+\.\s+(.*)$/);
            if (m) { if (!inList) { out.push('<ol>'); inList = true; listType = 'ol'; } out.push('<li>' + inline(m[1]) + '</li>'); return; }

            closeList();
            if (trimmed.indexOf('> ') === 0 || trimmed.indexOf('>') === 0) { out.push('<blockquote>' + inline(trimmed.replace(/^>+\s?/, '')) + '</blockquote>'); return; }
            out.push('<p>' + inline(trimmed) + '</p>');
        });

        if (inCode) out.push('<pre><code>' + escapeHtml(codeBuf.join('\n')) + '</code></pre>');
        closeList();
        return out.join('\n');
    }

    function inline(text) {
        var t = escapeHtml(text);
        t = t.replace(/`([^`]+)`/g, '<code>$1</code>');
        t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        t = t.replace(/\*([^*]+)\*/g, '<em>$1</em>');
        t = t.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
        return t;
    }

    /* ---------- State ---------- */
    var params = new URLSearchParams(window.location.search);
    var courseParam = params.get('course') || '';
    var lessonParam = params.get('lesson') || '';
    var courseId = /^\d+$/.test(String(courseParam || '').trim())
        ? String(courseParam).trim()
        : null;
    var lessonId = null;
    var loadedBlocks = [];

    /* Locate the lesson in the backend curriculum by its title. */
    function findLessonInCurriculum(curriculum, name) {
        var modules = (curriculum && curriculum.modules) || [];
        for (var i = 0; i < modules.length; i++) {
            var lessons = modules[i].lessons || [];
            for (var j = 0; j < lessons.length; j++) {
                if (slugify(lessons[j].title) === slugify(name || '')) {
                    return lessons[j];
                }
            }
        }
        return null;
    }

    var backLink = document.getElementById('backToCourse');
    if (backLink && courseParam) {
        backLink.href = 'course-editor.html?course=' + encodeURIComponent(courseParam);
    }

    /* Keep the quiz editor scoped to the lesson being edited. */
    var quizLink = document.getElementById('manageQuizLink');
    if (quizLink) {
        var quizParams = new URLSearchParams();
        if (courseParam) quizParams.set('course', courseParam);
        if (lessonParam) quizParams.set('lesson', lessonParam);
        var qs = quizParams.toString();
        quizLink.href = 'quiz-editor.html' + (qs ? '?' + qs : '');
    }

    function readBlocks() {
        var blocks = [];
        var cards = document.querySelectorAll('.content-block-editor');
        cards.forEach(function (card) {
            var type = card.querySelector('.block-type').value;
            var urlEl = card.querySelector('[data-field="url"]');
            var titleEl = card.querySelector('[data-field="title"]');
            var textEl = card.querySelector('[data-field="text"]');
            blocks.push({
                id: card.getAttribute('data-block-id') || '',
                type: type,
                url: urlEl ? urlEl.value.trim() : '',
                title: titleEl ? titleEl.value.trim() : '',
                text: textEl ? textEl.value : ''
            });
        });
        return blocks;
    }

    function blockBody(block) {
        if (block.type === 'markdown') {
            return '<div class="form-field">' +
                    '<label>Notes (Markdown)</label>' +
                    '<textarea data-field="text" rows="10" placeholder="Write notes in markdown...\n\n## Heading\n\n- list item\n\n**bold** and `code`">' +
                        escapeHtml(block.text || '') +
                    '</textarea>' +
                '</div>' +
                '<div class="markdown-live">' +
                    '<div class="markdown-live-label"><i class="fa-solid fa-eye"></i> Live Preview</div>' +
                    '<div class="markdown-live-body"></div>' +
                '</div>';
        }
        if (block.type === 'youtube') {
            return '<div class="form-field">' +
                    '<label>YouTube URL</label>' +
                    '<input type="url" data-field="url" placeholder="https://www.youtube.com/watch?v=..." value="' + escapeHtml(block.url || '') + '">' +
                '</div>' +
                '<div class="video-preview"></div>';
        }
        return '<div class="form-field">' +
                '<label>Title</label>' +
                '<input type="text" data-field="title" placeholder="Resource title" value="' + escapeHtml(block.title || '') + '">' +
            '</div>' +
            '<div class="form-field">' +
                '<label>Link URL</label>' +
                '<input type="url" data-field="url" placeholder="https://..." value="' + escapeHtml(block.url || '') + '">' +
            '</div>';
    }

    function renderBlocks(blocks) {
        var list = document.getElementById('blocksList');
        if (!list) return;
        blocks = blocks || readBlocks();
        if (blocks.length === 0) {
            list.innerHTML = '<div class="blocks-empty">No content blocks yet. Add your first video, article, notes, or PDF below.</div>';
            return;
        }

        list.innerHTML = blocks.map(function (block, index) {
            var typeOptions = BLOCK_TYPES.map(function (t) {
                return '<option value="' + t.value + '"' + (t.value === block.type ? ' selected' : '') + '>' + t.label + '</option>';
            }).join('');

            return '<div class="content-block-editor" data-index="' + index + '" data-block-id="' +
                ((block && block.id) || '') + '">' +
                '<div class="block-editor-head">' +
                    '<span class="block-order">#' + (index + 1) + '</span>' +
                    '<select class="block-type">' + typeOptions + '</select>' +
                    '<div class="block-editor-actions">' +
                        '<button type="button" class="btn btn-ghost btn-sm" data-action="up" title="Move up"><i class="fa-solid fa-arrow-up"></i></button>' +
                        '<button type="button" class="btn btn-ghost btn-sm" data-action="down" title="Move down"><i class="fa-solid fa-arrow-down"></i></button>' +
                        '<button type="button" class="btn btn-danger btn-sm" data-action="remove" title="Remove block"><i class="fa-solid fa-trash"></i></button>' +
                    '</div>' +
                '</div>' +
                '<div class="block-editor-body">' + blockBody(block) + '</div>' +
            '</div>';
        }).join('');

        refreshPreviews();
    }

    function refreshPreviews() {
        document.querySelectorAll('.content-block-editor').forEach(function (card) {
            var urlInput = card.querySelector('[data-field="url"]');
            var textArea = card.querySelector('[data-field="text"]');

            var vidPreview = card.querySelector('.video-preview');
            if (vidPreview) {
                var id = urlInput ? youtubeId(urlInput.value) : null;
                if (id) {
                    vidPreview.innerHTML = '<div class="video-thumb">' +
                        '<img src="https://img.youtube.com/vi/' + encodeURIComponent(id) + '/hqdefault.jpg" alt="Video preview" onerror="this.style.display=\'none\'">' +
                        '<i class="fa-solid fa-circle-play"></i>' +
                        '<span>This video will play inline for students</span>' +
                    '</div>';
                } else {
                    vidPreview.innerHTML = '<div class="video-thumb hint">' +
                        '<i class="fa-brands fa-youtube"></i>' +
                        '<span>Paste a YouTube link to preview the video here.</span>' +
                    '</div>';
                }
            }

            var liveBody = card.querySelector('.markdown-live-body');
            if (liveBody && textArea) {
                liveBody.innerHTML = renderMarkdown(textArea.value);
            }
        });
    }

    function addBlock(type) {
        var list = document.getElementById('blocksList');
        if (!list) return;
        if (list.querySelector('.blocks-empty')) list.innerHTML = '';

        var blocks = readBlocks();
        blocks.push({ type: type, url: '', title: '', text: '' });
        renderBlocks(blocks);
    }

    function removeBlock(card) {
        LearnovaConfirm.ask('Remove this content block?').then(function (ok) {
            if (!ok) return;
            card.remove();
            renderBlocks();
        });
    }

    function moveBlock(card, direction) {
        var parent = card.parentNode;
        var nodes = Array.prototype.slice.call(parent.children);
        var index = nodes.indexOf(card);
        var target = index + direction;
        if (target < 0 || target >= nodes.length) return;
        parent.insertBefore(card, direction > 0 ? nodes[target].nextSibling : nodes[target]);
        renderBlocks();
    }

    function toast(message) {
        var note = document.createElement('div');
        note.className = 'course-toast';
        note.textContent = message;
        document.body.appendChild(note);
        setTimeout(function () { if (note.parentNode) note.parentNode.removeChild(note); }, 2600);
    }

    function loadBlocks() {
        return LearnovaInstructorApi.getLessonContent(lessonId).then(function (blocks) {
            var list = blocks || [];
            loadedBlocks = [];
            var editorBlocks = list.map(function (block) {
                loadedBlocks.push({ id: block.blockId, type: block.blockType || 'markdown' });
                return {
                    id: block.blockId,
                    type: block.blockType || 'markdown',
                    url: block.resourceUrl || '',
                    title: block.title || '',
                    text: block.bodyMarkdown || ''
                };
            });
            renderBlocks(editorBlocks);
        }).catch(function () {
            loadedBlocks = [];
            renderBlocks([]);
        });
    }

    /* Save is a diff against the backend: delete removed blocks, recreate
       blocks whose type changed, update the rest, then sync the lesson
       title/description. */
    function save() {
        var title = document.getElementById('lessonTitle').value.trim();
        var description = document.getElementById('lessonDescription').value.trim();
        var current = readBlocks();

        var currentIds = current
            .filter(function (b) { return b.id; })
            .map(function (b) { return String(b.id); });
        var typeOf = {};
        loadedBlocks.forEach(function (b) { typeOf[String(b.id)] = b.type; });

        var removed = loadedBlocks.filter(function (b) {
            return currentIds.indexOf(String(b.id)) === -1;
        });

        var chain = Promise.resolve();

        removed.forEach(function (block) {
            chain = chain.then(function () {
                return LearnovaInstructorApi.deleteBlock(block.id);
            });
        });

        current.forEach(function (block, index) {
            var isText = block.type === 'markdown';
            var payload = {
                title: block.title || '',
                bodyMarkdown: isText ? block.text : '',
                resourceUrl: isText ? '' : block.url,
                sequenceOrder: index + 1
            };

            var hasId = !!block.id && currentIds.indexOf(String(block.id)) !== -1;
            var typeChanged = hasId && typeOf[String(block.id)] !== block.type;

            if (typeChanged) {
                chain = chain.then(function () {
                    return LearnovaInstructorApi.deleteBlock(block.id);
                });
            }

            if (hasId && !typeChanged) {
                chain = chain.then(function () {
                    return LearnovaInstructorApi.updateBlock(block.id, payload);
                });
            } else {
                chain = chain.then(function () {
                    return LearnovaInstructorApi.createBlock(lessonId, Object.assign({
                        blockType: block.type
                    }, payload));
                });
            }
        });

        return chain.then(function () {
            return LearnovaInstructorApi.updateLesson(lessonId, {
                title: title,
                description: description
            });
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var list = document.getElementById('blocksList');
        if (!list) return;

        if (!courseId) {
            toast('This editor needs a course. Open it from the course editor.');
            return;
        }

        var titleEl = document.getElementById('lessonTitle');
        if (titleEl && lessonParam) titleEl.value = lessonParam;

        renderBlocks([]);

        LearnovaInstructorApi.getCurriculum(courseId).then(function (curriculum) {
            var lesson = findLessonInCurriculum(curriculum, lessonParam);
            if (!lesson || !lesson.lessonId) {
                toast('Lesson "' + lessonParam + '" was not found in the curriculum. Add it from the course editor first.');
                return;
            }
            lessonId = lesson.lessonId;
            return loadBlocks();
        }).catch(function () {
            toast('Could not load the lesson from the backend.');
            renderBlocks([]);
        });

        document.getElementById('addBlockBtn').addEventListener('click', function () {
            addBlock(document.getElementById('blockTypeSelect').value);
        });

        list.addEventListener('change', function (event) {
            if (event.target.classList.contains('block-type')) {
                var card = event.target.closest('.content-block-editor');
                card.querySelector('.block-editor-body').innerHTML = blockBody({ type: event.target.value, url: '', title: '', text: '' });
                refreshPreviews();
                return;
            }
            refreshPreviews();
        });

        list.addEventListener('input', function () {
            refreshPreviews();
        });

        list.addEventListener('click', function (event) {
            var btn = event.target.closest('[data-action]');
            if (!btn) return;
            var card = event.target.closest('.content-block-editor');
            if (!card) return;
            var action = btn.getAttribute('data-action');
            if (action === 'remove') removeBlock(card);
            else if (action === 'up') moveBlock(card, -1);
            else if (action === 'down') moveBlock(card, 1);
        });

        document.getElementById('saveLessonBtn').addEventListener('click', function () {
            var title = document.getElementById('lessonTitle').value.trim();
            if (!title) {
                LearnovaToast.error('Please enter a lesson title.');
                return;
            }
            if (!lessonId) {
                LearnovaToast.error('This lesson is not attached to the backend yet. Save the curriculum from the course editor first.');
                return;
            }
            var count = readBlocks().length;
            save().then(function () {
                return loadBlocks();
            }).then(function () {
                toast('Lesson "' + title + '" saved. ' + count + ' content block(s).');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not save lesson.');
            });
        });
    });
})();
