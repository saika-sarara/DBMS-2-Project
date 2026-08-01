/* ==========================================================================
   Student Quiz Attempt
   Implements the spec's quiz flow (section 5):
   - A trigger randomly draws 5 questions from the instructor's 20-question bank.
   - Auto-grading on submit; passing score is 60% (3/5).
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
    var DAILY_LIMIT = LearnovaConstants.GRADING.DAILY_QUIZ_ATTEMPTS;
    var LETTERS = ['A', 'B', 'C', 'D'];

    var params = new URLSearchParams(window.location.search);
    var bypassMode = params.get('bypass') === '1';
    var lessonName = params.get('lesson') || 'Introduction to Databases';
    var slug = lessonName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

    var PASS_KEY = (bypassMode ? 'learnova_bypass_pass_' : 'learnova_quiz_pass_') + slug;
    var ATTEMPT_KEY = (bypassMode ? 'learnova_bypass_' : 'learnova_quiz_') + slug;

    /* ---------- 20-Question Bank ---------- */
    var questionBank = [
        {
            text: 'What does SQL stand for?',
            options: ['Structured Query Language', 'Simple Question Language', 'Standard Query List', 'Sequential Query Logic'],
            correct: 'A'
        },
        {
            text: 'Which clause is used to retrieve data from a table?',
            options: ['GET', 'SELECT', 'OPEN', 'EXTRACT'],
            correct: 'B'
        },
        {
            text: 'Which keyword sorts the results of a query?',
            options: ['SORT BY', 'GROUP BY', 'ORDER BY', 'ARRANGE BY'],
            correct: 'C'
        },
        {
            text: 'Which statement adds a new row to a table?',
            options: ['ADD ROW', 'INSERT INTO', 'INSERT ROW', 'PUT'],
            correct: 'B'
        },
        {
            text: 'What is a primary key?',
            options: ['The first key added to a table', 'A column that uniquely identifies each row', 'A reference to another table', 'An index on a column'],
            correct: 'B'
        },
        {
            text: 'What does a foreign key do?',
            options: ['Links a table to another table\'s primary key', 'Speeds up queries', 'Sets a unique constraint', 'Stores default values'],
            correct: 'A'
        },
        {
            text: 'Which command removes an entire table from the database?',
            options: ['DELETE TABLE', 'REMOVE TABLE', 'DROP TABLE', 'ERASE TABLE'],
            correct: 'C'
        },
        {
            text: 'Which command removes all rows but keeps the table structure?',
            options: ['DELETE', 'TRUNCATE', 'DROP', 'RESET'],
            correct: 'B'
        },
        {
            text: 'Which clause filters rows in a query?',
            options: ['HAVING', 'WHERE', 'FILTER', 'IF'],
            correct: 'B'
        },
        {
            text: 'Which statement returns only distinct values?',
            options: ['SELECT UNIQUE', 'SELECT DIFFERENT', 'SELECT DISTINCT', 'SELECT ONLY'],
            correct: 'C'
        },
        {
            text: 'What does a NULL value represent?',
            options: ['The number zero', 'An empty string', 'Missing or unknown data', 'A duplicate value'],
            correct: 'C'
        },
        {
            text: 'Which clause groups rows that have the same values?',
            options: ['GROUP BY', 'ORDER BY', 'HAVING BY', 'SORT BY'],
            correct: 'A'
        },
        {
            text: 'Which function counts the number of rows?',
            options: ['SUM()', 'COUNT()', 'TOTAL()', 'SIZE()'],
            correct: 'B'
        },
        {
            text: 'What does a database index do?',
            options: ['Deletes unused data', 'Speeds up data retrieval', 'Only enforces uniqueness', 'Permanently sorts the table'],
            correct: 'B'
        },
        {
            text: 'Which JOIN returns only the matching rows from both tables?',
            options: ['INNER JOIN', 'LEFT JOIN', 'FULL JOIN', 'CROSS JOIN'],
            correct: 'A'
        },
        {
            text: 'What is a database transaction?',
            options: ['A single SELECT query', 'A unit of work executed atomically', 'A backup of data', 'A table constraint'],
            correct: 'B'
        },
        {
            text: 'Which command deletes a column from an existing table?',
            options: ['DROP COLUMN', 'DELETE COLUMN', 'REMOVE COLUMN', 'ERASE COLUMN'],
            correct: 'A'
        },
        {
            text: 'Which ACID property guarantees a transaction completes fully or not at all?',
            options: ['Consistency', 'Isolation', 'Atomicity', 'Durability'],
            correct: 'C'
        },
        {
            text: 'What is normalization?',
            options: ['Encrypting data', 'Organizing data to reduce redundancy', 'Compressing data', 'Indexing all columns'],
            correct: 'B'
        },
        {
            text: 'Which statement updates existing records in a table?',
            options: ['MODIFY', 'UPDATE', 'CHANGE', 'ALTER'],
            correct: 'B'
        }
    ];

    /* ---------- Attempt tracking (3 per day, resets at midnight) ---------- */
    function todayStr() {
        var d = new Date();
        return d.getFullYear() + '-' +
            String(d.getMonth() + 1).padStart(2, '0') + '-' +
            String(d.getDate()).padStart(2, '0');
    }

    function getAttemptRecord() {
        var raw = localStorage.getItem(ATTEMPT_KEY);
        var record = raw ? JSON.parse(raw) : { date: '', used: 0 };
        if (record.date !== todayStr()) {
            record = { date: todayStr(), used: 0 };
        }
        return record;
    }

    function saveAttemptRecord(record) {
        localStorage.setItem(ATTEMPT_KEY, JSON.stringify(record));
    }

    function attemptsUsed() {
        return getAttemptRecord().used;
    }

    function attemptsLeft() {
        return DAILY_LIMIT - attemptsUsed();
    }

    /* ---------- Helpers ---------- */
    function shuffle(array) {
        for (var i = array.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = array[i];
            array[i] = array[j];
            array[j] = tmp;
        }
        return array;
    }

    function pickQuestions() {
        return shuffle(questionBank.slice()).slice(0, QUESTIONS_PER_QUIZ);
    }

    /* ---------- Rendering ---------- */
    var currentQuestions = [];
    var resultLocked = false;

    function questionHtml(question, index) {
        var optionsHtml = question.options.map(function (option, i) {
            return '<label class="attempt-option" data-correct="' + (LETTERS[i] === question.correct) + '">' +
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
        var resultBox = document.getElementById('quizResult');
        if (resultBox) resultBox.innerHTML = '';

        var existing = mainContent.querySelectorAll('.quiz-attempt-question');
        for (var i = existing.length - 1; i >= 0; i--) {
            existing[i].parentNode.removeChild(existing[i]);
        }

        currentQuestions = pickQuestions();
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

        if (counterEl) {
            counterEl.textContent = 'Attempt ' + (attemptsUsed() + 1) + '/' + DAILY_LIMIT + ' today · Resets at midnight';
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
    function revealAnswers() {
        var cards = document.querySelectorAll('.quiz-attempt-question');
        cards.forEach(function (card, idx) {
            var question = currentQuestions[idx];
            if (!question) return;
            var options = card.querySelectorAll('.attempt-option');
            for (var i = 0; i < options.length; i++) {
                var input = options[i].querySelector('input');
                var letter = LETTERS[i];
                input.disabled = true;
                if (letter === question.correct) {
                    options[i].classList.add('correct');
                } else if (input.checked) {
                    options[i].classList.add('wrong');
                }
            }
        });
    }

    function showResult(score, passed) {
        var resultBox = document.getElementById('quizResult');
        if (!resultBox) return;

        if (passed) {
            if (bypassMode) {
                localStorage.setItem(PASS_KEY, '1');
                resultBox.innerHTML =
                    '<div class="quiz-result pass">' +
                        '<div class="quiz-result-score">Score: ' + score + '% — Passed</div>' +
                        '<p>You met the ' + PASSING_SCORE + '% passing score. The prerequisite for this course has been cleared — you can now enroll.</p>' +
                        '<a class="btn btn-primary" href="course-detail.html">Back to Course</a>' +
                    '</div>';
            } else {
                localStorage.setItem(PASS_KEY, '1');
                resultBox.innerHTML =
                    '<div class="quiz-result pass">' +
                        '<div class="quiz-result-score">Score: ' + score + '% — Passed</div>' +
                        '<p>You met the ' + PASSING_SCORE + '% passing score. Correct answers are revealed, the lesson is marked completed, and the next lesson is unlocked.</p>' +
                        '<a class="btn btn-primary" href="course-detail.html?course=database-design">Back to Course</a>' +
                    '</div>';
            }
            revealAnswers();
        } else {
            var record = getAttemptRecord();
            record.used += 1;
            saveAttemptRecord(record);

            if (record.used >= DAILY_LIMIT) {
                lockForToday('You have used all ' + DAILY_LIMIT + ' attempts for today. The quiz unlocks again at midnight (00:00).');
                return;
            }

            resultBox.innerHTML =
                '<div class="quiz-result fail">' +
                    '<div class="quiz-result-score">Score: ' + score + '% — Not passed</div>' +
                    '<p>Below the ' + PASSING_SCORE + '% passing score. Correct answers stay hidden until you pass. ' +
                    'Attempts left today: ' + (DAILY_LIMIT - record.used) + ' (resets at midnight).</p>' +
                    '<button class="btn btn-outline" id="retryBtn">Try Again</button>' +
                '</div>';
        }
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
                alert('Please answer all ' + QUESTIONS_PER_QUIZ + ' questions before submitting.');
                return;
            }

            var correct = 0;
            currentQuestions.forEach(function (question, idx) {
                var name = 'q' + (idx + 1);
                var selected = document.querySelector('input[name="' + name + '"]:checked');
                if (selected && selected.value === question.correct) {
                    correct += 1;
                }
            });

            var score = Math.round((correct / QUESTIONS_PER_QUIZ) * 100);
            var passed = score >= PASSING_SCORE;
            resultLocked = true;
            showResult(score, passed);
            updateContext();
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
            renderQuiz();
        }
    });

    /* ---------- Boot ---------- */
    if (localStorage.getItem(PASS_KEY)) {
        var main = document.querySelector('.main-content');
        var sub = main && main.querySelector('.quiz-submit-row');
        if (sub) sub.style.display = 'none';
        var box = document.getElementById('quizResult');
        if (box) {
            box.innerHTML =
                '<div class="quiz-result pass">' +
                    '<div class="quiz-result-score">Already passed</div>' +
                    '<p>' + (bypassMode ? 'This prerequisite has already been cleared.' : 'This lesson is already completed.') + '</p>' +
                    '<a class="btn btn-primary" href="course-detail.html?course=database-design">Back to Course</a>' +
                '</div>';
        }
        return;
    }

    if (attemptsUsed() >= DAILY_LIMIT) {
        lockForToday('You have used all ' + DAILY_LIMIT + ' attempts for today. The quiz unlocks again at midnight (00:00).');
        return;
    }

    renderQuiz();
})();
