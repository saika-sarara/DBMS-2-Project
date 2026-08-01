/* ==========================================================================
   Instructor Quiz Editor (quiz-editor.html)
   Manage the 20-MCQ question bank for a lesson. The product rule: students
   are shown 5 randomly selected questions from the bank of 20.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', function () {
    var lessonName = new URLSearchParams(window.location.search).get('lesson') || 'Introduction to Databases';
    var titleEl = document.getElementById('quizLessonTitle');
    var subtitleEl = document.getElementById('lessonSubtitle');
    if (titleEl) titleEl.textContent = 'Quiz for: ' + lessonName;
    if (subtitleEl) subtitleEl.textContent = 'Create and manage the 20 MCQ questions for "' + lessonName + '".';

    var bank = mockQuestions.slice();
    var bankList = document.getElementById('questionBankList');
    var bankCount = document.getElementById('bankCount');

    function renderBank() {
        if (!bankList || !bankCount) return;
        bankList.innerHTML = '';
        bank.forEach(function (item, index) {
            var number = index + 1;
            var block = document.createElement('div');
            block.className = 'question-block';

            var optionsHtml = item.options.map(function (opt, i) {
                var letter = String.fromCharCode(65 + i);
                return '<div class="option-pill">[' + letter + '] ' + opt + '</div>';
            }).join('');

            block.innerHTML =
                '<div class="question-text">Q' + number + ': ' + item.q + '</div>' +
                '<div class="question-options">' + optionsHtml + '</div>' +
                '<div class="question-block-foot">' +
                    '<span class="question-correct">✅ Correct: ' + item.answer + '</span>' +
                    '<button class="question-delete">🗑️ Delete</button>' +
                '</div>';

            block.querySelector('.question-delete').addEventListener('click', function () {
                bank.splice(index, 1);
                renderBank();
            });

            bankList.appendChild(block);
        });
        bankCount.textContent = 'Total Questions: ' + bank.length + '/20';
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
                alert('Please fill in the question text and all four options.');
                return;
            }

            bank.unshift({ q: text, options: [a, b, c, d], answer: answer });

            document.getElementById('qText').value = '';
            document.getElementById('optA').value = '';
            document.getElementById('optB').value = '';
            document.getElementById('optC').value = '';
            document.getElementById('optD').value = '';

            renderBank();
        });
    }

    var saveBtn = document.getElementById('saveQuizBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function () {
            alert('Quiz saved and assigned to "' + lessonName + '"! Students will be shown 5 random questions.');
        });
    }

    renderBank();
});

/* 20 mock questions (simulating the instructor's saved bank) */
var mockQuestions = [
    { q: 'What does SQL stand for?', options: ['Structured Query Language', 'Simple Question Language', 'Standard Query List', 'Sequential Query Logic'], answer: 'A' },
    { q: 'Which clause is used to retrieve data from a table?', options: ['GET', 'SELECT', 'OPEN', 'EXTRACT'], answer: 'B' },
    { q: 'Which keyword sorts the results of a query?', options: ['SORT BY', 'GROUP BY', 'ORDER BY', 'ARRANGE BY'], answer: 'C' },
    { q: 'Which statement is used to add a new row to a table?', options: ['ADD ROW', 'INSERT INTO', 'INSERT ROW', 'PUT'], answer: 'B' },
    { q: 'What is a primary key?', options: ['The first key added to a table', 'A column that uniquely identifies each row', 'A reference to another table', 'An index on a column'], answer: 'B' },
    { q: 'Which operator selects values within a given range?', options: ['BETWEEN', 'IN RANGE', 'LIKE', 'WITHIN'], answer: 'A' },
    { q: 'Which join returns only the matching rows from both tables?', options: ['LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'CROSS JOIN'], answer: 'C' },
    { q: 'What does COUNT(*) return?', options: ['The number of non-null rows in a column', 'The total number of rows in the table', 'The sum of a numeric column', 'The first row of the table'], answer: 'B' },
    { q: 'Which keyword removes duplicate values from the result?', options: ['UNIQUE', 'SEPARATE', 'NO DUP', 'DISTINCT'], answer: 'D' },
    { q: 'What is a foreign key?', options: ['The primary key of the same table', 'An alternate key', 'A column that references another table\'s primary key', 'A clustered index'], answer: 'C' },
    { q: 'Which command deletes rows from a table?', options: ['REMOVE', 'DELETE FROM', 'DROP ROW', 'CLEAR'], answer: 'B' },
    { q: 'Which clause filters groups created by GROUP BY?', options: ['WHERE', 'FILTER', 'HAVING', 'LIMIT'], answer: 'C' },
    { q: 'What is a transaction?', options: ['A single query', 'A sequence of operations treated as one unit', 'A backup job', 'A stored procedure'], answer: 'B' },
    { q: 'Which command removes an entire table and its structure?', options: ['DELETE TABLE', 'REMOVE TABLE', 'DROP TABLE', 'ERASE TABLE'], answer: 'C' },
    { q: 'Which function returns the largest value in a column?', options: ['TOP()', 'MAX()', 'LARGEST()', 'HIGHEST()'], answer: 'B' },
    { q: 'What does a LEFT JOIN preserve?', options: ['Only matching rows', 'All rows from the right table', 'All rows from the left table plus matching right rows', 'No rows'], answer: 'C' },
    { q: 'Which statement creates a new table?', options: ['ADD TABLE', 'CREATE TABLE', 'MAKE TABLE', 'BUILD TABLE'], answer: 'B' },
    { q: 'What does an index speed up?', options: ['Data deletion', 'Table creation', 'Query retrieval', 'User login'], answer: 'C' },
    { q: 'Which constraint ensures all values in a column are different?', options: ['UNIQUE', 'CHECK', 'NOT NULL', 'DEFAULT'], answer: 'A' },
    { q: 'What does ETL stand for in a data pipeline?', options: ['Export, Transfer, Log', 'Execute, Test, Launch', 'Extract, Transform, Load', 'Encode, Transmit, Listen'], answer: 'C' }
];
