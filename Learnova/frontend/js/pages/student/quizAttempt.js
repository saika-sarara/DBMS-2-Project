/* ==========================================================================
   Student Quiz Attempt
   Implements the spec's quiz flow (section 5):
   - The server draws 5 random questions from the instructor's 20-question
     bank (answers never reach the client before grading).
   - Auto-grading on submit (server-side / mock); passing score is 60% (3/5).
   - 3 attempts per day per quiz; the counter resets at 00:00 midnight.
   - On pass: correct answers are revealed, the lesson is marked completed and
     the next lesson is unlocked.
   - On fail: correct answers stay hidden; the student can retry (daily limit).
   - Bypass mode (?bypass=1): the same rules, but passing clears the
     prerequisite for a course (spec 3.3).
   ========================================================================== */
(function () {
    'use strict';

    var QUESTIONS_PER_QUIZ = LearnovaConstants.QUIZ_DEFAULTS.RANDOM_PER_STUDENT;
    var PASSING_SCORE = LearnovaConstants.GRADING.PASSING_SCORE;
    var LETTERS = ['A', 'B', 'C', 'D'];

    var params = new URLSearchParams(window.location.search);
    var bypassMode = params.get('bypass') === '1';
    var lessonName = params.get('lesson') || 'Introduction to Databases';
    var courseSlug = params.get('course') || 'database-design';
    var lessonSlug = lessonName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

    var currentQuestions = [];
    var resultLocked = false;
    var statusInfo = null;

    /* ---------- Rendering ---------- */

    function questionHtml(question, index) {
        var optionsHtml = question.options.map(function (option, i) {
            return '<label class="attempt-option">' +
                '<input type="radio" name="q' + (index + 1) + '" value="' + LETTERS[i] + '">' +
                '<span class="opt-letter">' + LETTERS[i] + '</span>' +
                option +
                '</label>';
        }).join('');

        return '<div class="quiz-attempt-question" data-q="' + (index + 1) + '">' +
            '<div class="attempt-question-text">' + (index + 1) + '. ' + question.text + '</div>' +
            '<div class="attempt-options">' + optionsHtml + '</div>' +
            '</div>';
    }

    function renderQuiz() {
        var mainContent = document.querySelector('.main-content');
        if (!mainContent) return;

        var submitRow = mainContent.querySelector('.quiz-submit-row');
        if (submitRow) submitRow.style.display = '';
        var resultBox = document.getElementById('quizResult');
        if (resultBox) resultBox.innerHTML = '';

        var existing = mainContent.querySelectorAll('.quiz-attempt-question');
        for (var i = existing.length - 1; i >= 0; i--) {
            existing[i].parentNode.removeChild(existing[i]);
        }

        var html = currentQuestions.map(questionHtml).join('');
        if (submitRow) {
            submitRow.insertAdjacentHTML('beforebegin', html);
        } else {
            mainContent.insertAdjacentHTML('beforeend', html);
        }

        updateContext();
        resultLocked = false;
    }

    function updateContext() {
        var titleEl = document.getElementById('quizIntroTitle');
        var metaEl = document.getElementById('quizIntroMeta');
        var counterEl = document.getElementById('attemptCounter');
        var pageTitle = document.getElementById('quizPageTitle');

        if (bypassMode) {
            if (pageTitle) pageTitle.textContent = 'Bypass Exam';
            if (titleEl) titleEl.textContent = 'Bypass Exam: ' + lessonName;
            if (metaEl) metaEl.textContent = 'Questions auto-generated from all lessons of the prerequisite course. Pass with ' +
                PASSING_SCORE + '% to clear it.';
        } else {
            if (pageTitle) pageTitle.textContent = 'Lesson Quiz';
            if (titleEl) titleEl.textContent = lessonName;
            if (metaEl) metaEl.textContent = QUESTIONS_PER_QUIZ + ' questions · Picked randomly from your instructor\'s 20-question bank.';
        }

        if (counterEl && statusInfo) {
            var used = Math.max(0, statusInfo.limit - statusInfo.attemptsLeft);
            counterEl.textContent = 'Attempt ' + (used + 1) + '/' + statusInfo.limit + ' today · Resets at midnight';
        }
    }

    function lockForToday(message) {
        var mainContent = document.querySelector('.main-content');
        var submitRow = mainContent && mainContent.querySelector('.quiz-submit-row');
        var resultBox = document.getElementById('quizResult');

        var existing = mainContent.querySelectorAll('.quiz-attempt-question');
        for (var i = existing.length - 1; i >= 0; i--) {
            existing[i].parentNode.removeChild(existing[i]);
        }
        if (submitRow) submitRow.style.display = 'none';

        if (resultBox) {
            resultBox.innerHTML =
                '<div class="quiz-result fail">' +
                '<div class="quiz-result-score">Daily attempt limit reached</div>' +
                '<p>' + message + '</p>' +
                '</div>';
        }
        resultLocked = true;
    }

    /* Reveal the answer key after a pass (spec 5.4). */
    function revealAnswers(correctAnswers) {
        var cards = document.querySelectorAll('.quiz-attempt-question');
        cards.forEach(function (card, idx) {
            var question = currentQuestions[idx];
            if (!question) return;
            var correctLetter = null;
            (correctAnswers || []).forEach(function (ca) {
                if (String(ca.id) === String(question.id)) correctLetter = ca.correct;
            });
            var options = card.querySelectorAll('.attempt-option');
            for (var i = 0; i < options.length; i++) {
                var input = options[i].querySelector('input');
                var letter = LETTERS[i];
                input.disabled = true;
                if (letter === correctLetter) {
                    options[i].classList.add('correct');
                } else if (input.checked) {
                    options[i].classList.add('wrong');
                }
            }
        });
    }

    function backToCourse() {
        return 'course-detail.html?course=' + encodeURIComponent(courseSlug);
    }

    function showResult(score, passed, result) {
        var resultBox = document.getElementById('quizResult');
        if (!resultBox) return;

        if (passed) {
            resultBox.innerHTML =
                '<div class="quiz-result pass">' +
                '<div class="quiz-result-score">Score: ' + score + '% — Passed</div>' +
                '<p>' + (bypassMode
                    ? 'You met the ' + PASSING_SCORE + '% passing score. The prerequisite for this course has been cleared — you can now enroll.'
                    : 'You met the ' + PASSING_SCORE + '% passing score. Correct answers are revealed, the lesson is marked completed, and the next lesson is unlocked.') +
                '</p>' +
                '<a class="btn btn-primary" href="' + backToCourse() + '">Back to Course</a>' +
                '</div>';
            revealAnswers(result.correctAnswers || []);
        } else {
            if (result.exhausted) {
                lockForToday('You have used all ' + result.attemptsLeft + ' attempts for today. The quiz unlocks again at midnight (00:00).');
                return;
            }
            resultBox.innerHTML =
                '<div class="quiz-result fail">' +
                '<div class="quiz-result-score">Score: ' + score + '% — Not passed</div>' +
                '<p>Below the ' + PASSING_SCORE + '% passing score. Correct answers stay hidden until you pass. ' +
                'Attempts left today: ' + result.attemptsLeft + ' (resets at midnight).</p>' +
                '<button class="btn btn-outline" id="retryBtn">Try Again</button>' +
                '</div>';
        }
    }

    function showAlreadyPassed() {
        var main = document.querySelector('.main-content');
        var sub = main && main.querySelector('.quiz-submit-row');
        if (sub) sub.style.display = 'none';
        var box = document.getElementById('quizResult');
        if (box) {
            box.innerHTML =
                '<div class="quiz-result pass">' +
                '<div class="quiz-result-score">Already passed</div>' +
                '<p>' + (bypassMode ? 'This prerequisite has already been cleared.' : 'This lesson is already completed.') + '</p>' +
                '<a class="btn btn-primary" href="' + backToCourse() + '">Back to Course</a>' +
                '</div>';
        }
        resultLocked = true;
    }

    function drawQuestions() {
        return LearnovaQuizApi.randomize(
            lessonSlug,
            QUESTIONS_PER_QUIZ,
            courseSlug,
            bypassMode
        ).then(function (questions) {
            currentQuestions = questions;
        });
    }

    /* ---------- Interactions ---------- */
    document.addEventListener('click', function (event) {
        var option = event.target.closest('.attempt-option');
        if (!option || resultLocked) return;

        var input = option.querySelector('input');
        if (input.disabled) return;

        var group = option.parentNode;
        var name = input.name;

        var radios = group.querySelectorAll('input[type="radio"][name="' + name + '"]');
        for (var i = 0; i < radios.length; i++) {
            radios[i].checked = false;
            radios[i].closest('.attempt-option').classList.remove('selected');
        }

        input.checked = true;
        option.classList.add('selected');
    });

    var submitBtn = document.getElementById('submitBtn');
    if (submitBtn) {
        submitBtn.addEventListener('click', function () {
            if (resultLocked) return;

            var answered = document.querySelectorAll('input[type="radio"]:checked');
            if (answered.length < QUESTIONS_PER_QUIZ) {
                LearnovaToast.error('Please answer all ' + QUESTIONS_PER_QUIZ + ' questions before submitting.');
                return;
            }

            var answers = [];
            currentQuestions.forEach(function (question, idx) {
                var name = 'q' + (idx + 1);
                var selected = document.querySelector('input[name="' + name + '"]:checked');
                answers.push({ id: question.id, selected: selected ? selected.value : null });
            });

            resultLocked = true;
            LearnovaProgressApi.markQuizAttempt(courseSlug, lessonName, { answers: answers, bypass: bypassMode })
                .then(function (result) {
                    if (statusInfo) statusInfo.attemptsLeft = result.attemptsLeft;
                    if (result.alreadyPassed) {
                        showAlreadyPassed();
                        return;
                    }
                    showResult(result.score, result.passed, result);
                    updateContext();
                })
                .catch(function (err) {
                    resultLocked = false;
                    LearnovaToast.error((err && err.message) || 'Could not submit your attempt.');
                });
        });
    }

    var clearBtn = document.getElementById('clearBtn');
    if (clearBtn) {
        clearBtn.addEventListener('click', function () {
            if (resultLocked) return;
            var options = document.querySelectorAll('.attempt-option');
            for (var i = 0; i < options.length; i++) {
                options[i].classList.remove('selected');
                options[i].querySelector('input').checked = false;
            }
        });
    }

    document.addEventListener('click', function (event) {
        var retry = event.target.closest('#retryBtn');
        if (retry) {
            drawQuestions().then(function () {
                renderQuiz();
            });
        }
    });

    /* ---------- Boot ---------- */
    LearnovaQuizApi.status(lessonSlug, bypassMode, courseSlug).then(function (status) {
        statusInfo = status;
        if (status.passed) {
            showAlreadyPassed();
            return;
        }
        if (status.exhausted) {
            lockForToday('You have used all ' + status.limit + ' attempts for today. The quiz unlocks again at midnight (00:00).');
            return;
        }
        return drawQuestions().then(function () {
            renderQuiz();
        });
    }).catch(function (err) {
        LearnovaToast.error((err && err.message) || 'Could not load the quiz.');
    });
})();
