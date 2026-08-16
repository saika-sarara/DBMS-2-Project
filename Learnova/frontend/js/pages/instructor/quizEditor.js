/* ==========================================================================
   Instructor Quiz Editor (quiz-editor.html)
   Manage the 20-MCQ question bank for a lesson through LearnovaQuizApi.
   The product rule: students are shown 5 randomly selected questions
   from the bank of 20.
   ========================================================================== */

(function () {
    'use strict';

    var params = new URLSearchParams(window.location.search);
    var lessonName = params.get('lesson') || 'Introduction to Databases';
    var titleEl = document.getElementById('quizLessonTitle');
    var subtitleEl = document.getElementById('lessonSubtitle');
    if (titleEl) titleEl.textContent = 'Quiz for: ' + lessonName;
    if (subtitleEl) subtitleEl.textContent = 'Create and manage the 20 MCQ questions for "' + lessonName + '".';

    var bank = [];
    var bankList = document.getElementById('questionBankList');
    var bankCount = document.getElementById('bankCount');

    function toast(message) {
        var note = document.createElement('div');
        note.className = 'course-toast';
        note.textContent = message;
        document.body.appendChild(note);
        setTimeout(function () { if (note.parentNode) note.parentNode.removeChild(note); }, 2600);
    }

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function renderBank() {
        if (!bankList || !bankCount) return;
        bankList.innerHTML = '';
        bank.forEach(function (item, index) {
            var number = index + 1;
            var block = document.createElement('div');
            block.className = 'question-block';

            var optionsHtml = (item.options || []).map(function (opt, i) {
                var letter = String.fromCharCode(65 + i);
                return '<div class="option-pill">[' + letter + '] ' + esc(opt) + '</div>';
            }).join('');

            block.innerHTML =
                '<div class="question-text">Q' + number + ': ' + esc(item.text) + '</div>' +
                '<div class="question-options">' + optionsHtml + '</div>' +
                '<div class="question-block-foot">' +
                    '<span class="question-correct">&#9989; Correct: ' + esc(item.correct) + '</span>' +
                    '<button class="question-delete" data-id="' + esc(item.id) + '">&#128465; Delete</button>' +
                '</div>';

            block.querySelector('.question-delete').addEventListener('click', function () {
                var id = this.getAttribute('data-id');
                LearnovaConfirm.ask('Delete this question?').then(function (ok) {
                    if (!ok) return;
                    LearnovaQuizApi.remove(id).then(function () {
                        loadBank();
                        toast('Question deleted.');
                    }).catch(function (err) {
                        toast((err && err.message) || 'Could not delete question.');
                    });
                });
            });

            bankList.appendChild(block);
        });
        bankCount.textContent = 'Total Questions: ' + bank.length + '/20';
    }

    function loadBank() {
        LearnovaQuizApi.list(lessonName).then(function (questions) {
            bank = questions || [];
            renderBank();
        }).catch(function (err) {
            toast((err && err.message) || 'Could not load the question bank.');
        });
    }

    var addBtn = document.getElementById('addQuestionBtn');
    if (addBtn) {
        addBtn.addEventListener('click', function () {
            var text = document.getElementById('qText').value.trim();
            var a = document.getElementById('optA').value.trim();
            var b = document.getElementById('optB').value.trim();
            var c = document.getElementById('optC').value.trim();
            var d = document.getElementById('optD').value.trim();
            var answer = document.getElementById('correctAns').value;

            if (!text || !a || !b || !c || !d) {
                LearnovaToast.error('Please fill in the question text and all four options.');
                return;
            }

            LearnovaQuizApi.create(lessonName, { text: text, options: [a, b, c, d], correct: answer }).then(function () {
                document.getElementById('qText').value = '';
                document.getElementById('optA').value = '';
                document.getElementById('optB').value = '';
                document.getElementById('optC').value = '';
                document.getElementById('optD').value = '';
                loadBank();
                toast('Question added to the bank.');
            }).catch(function (err) {
                toast((err && err.message) || 'Could not add question.');
            });
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        loadBank();
    });
})();
