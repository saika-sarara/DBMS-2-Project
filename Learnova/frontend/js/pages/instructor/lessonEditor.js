/* ==========================================================================
   Instructor Lesson Editor (lesson-editor.html)
   Builds a lesson from content blocks: video (YouTube), blog/article link,
   notes (markdown), and PDF link. YouTube URLs get a live embed preview.
   Persists through LearnovaCourseApi so the student lesson view can render it.
   ========================================================================== */
(function () {
    'use strict';

    var BLOCK_TYPES = [
        { value: 'video', label: 'Video (YouTube)' },
        { value: 'article', label: 'Blog / Article Link' },
        { value: 'notes', label: 'Notes (Markdown)' },
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

    var backLink = document.getElementById('backToCourse');
    if (backLink && courseParam) {
        backLink.href = 'course-editor.html?course=' + encodeURIComponent(courseParam);
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
                type: type,
                url: urlEl ? urlEl.value.trim() : '',
                title: titleEl ? titleEl.value.trim() : '',
                text: textEl ? textEl.value : ''
            });
        });
        return blocks;
    }

    function blockBody(block) {
        if (block.type === 'notes') {
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
        if (block.type === 'video') {
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

            return '<div class="content-block-editor" data-index="' + index + '">' +
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

    document.addEventListener('DOMContentLoaded', function () {
        var list = document.getElementById('blocksList');
        if (!list) return;

        /* Prefill from saved record via the API */
        if (!courseParam) {
            toast('This editor needs a course. Open it from the course editor.');
        } else {
            LearnovaCourseApi.getLesson(courseParam, lessonParam || 'lesson').then(function (saved) {
                if (saved && saved.title) {
                    var titleEl = document.getElementById('lessonTitle');
                    var descEl = document.getElementById('lessonDescription');
                    if (titleEl) titleEl.value = saved.title;
                    if (descEl && saved.description) descEl.value = saved.description;
                }
            }).catch(function () { /* brand-new lesson: leave blank */ });
        }

        renderBlocks();

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
            var record = {
                title: title,
                description: document.getElementById('lessonDescription').value.trim(),
                blocks: readBlocks()
            };
            if (!courseParam) {
                LearnovaToast.error('This editor needs a course. Open it from the course editor.');
                return;
            }
            LearnovaCourseApi.setLesson(courseParam, lessonParam || title, record).then(function () {
                toast('Lesson "' + title + '" saved. ' + record.blocks.length + ' content block(s).');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not save lesson.');
            });
        });
    });
})();
