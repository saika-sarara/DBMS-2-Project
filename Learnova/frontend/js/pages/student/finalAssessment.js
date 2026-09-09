/* ==========================================================================
   Student Final Assessment (final-assessment.html)
   Wires the real backend final-assessment endpoints:
   - status: eligibility state from fn_final_assessment_status
   - start attempt: server returns a snapshot without correct answers
   - save-answer on each selection (PUT answers/{questionId})
   - submit: server-side grading, course completion + certificate on pass
   - history: submitted attempts for the course
   ========================================================================== */
(function () {
    'use strict';

    var LETTERS = ['A', 'B', 'C', 'D'];

    var params = new URLSearchParams(window.location.search);
    var rawCourse = params.get('course') || '';
    var courseId = 0;

    var course = null;
    var statusInfo = {};
    var attempt = null;
    var currentQuestions = [];
    var selections = {};
    var savedAnswers = {};
    var resultLocked = false;

    function el(id) { return document.getElementById(id); }

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function formatDate(value) {
        if (!value) return '-';
        var d = new Date(value);
        if (isNaN(d.getTime())) return String(value);
        return d.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
    }

    function statusCardHtml(body) {
        return '<div class="assessment-status">' + body + '</div>';
    }

    function backToCourse() {
        return 'course-detail.html?course=' + encodeURIComponent(courseId);
    }

    function resolveCourseId(raw) {
        var trimmed = String(raw || '').trim();
        if (/^\d+$/.test(trimmed)) return Promise.resolve(Number(trimmed));
        return LearnovaCourseApi.list().then(function (cards) {
            for (var i = 0; i < (cards || []).length; i++) {
                if (String(cards[i].slug) === trimmed) {
                    var id = cards[i].id !== undefined && cards[i].id !== null ? cards[i].id : null;
                    return Number(id);
                }
            }
            return 0;
        }).catch(function () { return 0; });
    }

    function setIntro() {
        var pageTitle = el('assessmentPageTitle');
        var title = el('assessmentIntroTitle');
        var meta = el('assessmentIntroMeta');
        var counter = el('assessmentCounter');

        if (pageTitle) pageTitle.textContent = 'Final Assessment';

        if (title) {
            title.textContent = (course && (course.title || course.shortDescription))
                ? (course.title || course.shortDescription)
                : 'Final Assessment';
        }

        if (meta) {
            if (statusInfo.assessmentId && statusInfo.questionsPerAttempt) {
                meta.textContent = statusInfo.questionsPerAttempt +
                    ' questions · pass at ' + statusInfo.passingScore +
                    '% · course final assessment';
            } else {
                meta.textContent = 'Course final assessment';
            }
        }

        if (counter) {
            counter.textContent = statusInfo.remainingAttempts > 0
                ? 'Attempts left today: ' + statusInfo.remainingAttempts
                : 'No attempts left today';
        }
    }

    function renderNotEnrolled() {
        var box = el('assessmentStatus');
        if (!box) return;
        box.innerHTML = statusCardHtml(
            '<h2>Not enrolled</h2>' +
            '<p>Enroll in this course to unlock its lessons and final assessment.</p>' +
            '<a class="btn btn-outline" href="' + esc(backToCourse()) + '">Back to Course</a>'
        );
    }

    function renderNoAssessment() {
        var box = el('assessmentStatus');
        if (!box) return;
        box.innerHTML = statusCardHtml(
            '<h2>No final assessment</h2>' +
            '<p>This course does not have an active final assessment right now.</p>' +
            '<a class="btn btn-outline" href="' + esc(backToCourse()) + '">Back to Course</a>'
        );
    }

    function statsHtml() {
        return '<div class="assessment-stats">' +
            '<span class="stat-pill">' + (statusInfo.questionsPerAttempt || 0) + ' questions per attempt</span>' +
            '<span class="stat-pill">Pass at ' + (statusInfo.passingScore || 0) + '%</span>' +
            '<span class="stat-pill">' + (statusInfo.attemptsToday || 0) + ' attempts today</span>' +
            '<span class="stat-pill">' + (statusInfo.remainingAttempts || 0) + ' left today</span>' +
            '</div>';
    }

    function renderStatus() {
        var box = el('assessmentStatus');
        if (!box) return;

        if (!statusInfo.assessmentId) {
            if (statusInfo.enrolled === false) renderNotEnrolled();
            else renderNoAssessment();
            return;
        }

        var body;

        if (statusInfo.alreadyPassed) {
            body =
                '<h2>You passed</h2>' +
                '<p>You have already passed this course final assessment.</p>' +
                '<div class="assessment-stats">' +
                    '<a class="btn btn-primary" href="certificates.html">View Certificates</a>' +
                    '<a class="btn btn-outline" href="' + esc(backToCourse()) + '">Back to Course</a>' +
                '</div>';
        } else if (statusInfo.eligible) {
            body =
                '<h2>Ready to take the final assessment</h2>' +
                '<p>You have completed the course lessons. Pass the final assessment to complete the course and earn your certificate.</p>' +
                statsHtml() +
                '<button class="btn btn-primary" id="startBtn" type="button">Start Final Assessment</button>';
        } else if (!statusInfo.contentComplete) {
            body =
                '<h2>Lessons not finished</h2>' +
                '<p>Finish every lesson in the course before the final assessment unlocks.</p>' +
                statsHtml();
        } else {
            body =
                '<h2>No attempts left today</h2>' +
                '<p>You have used all your attempts for today. The final assessment unlocks again at midnight.</p>' +
                statsHtml();
        }

        box.innerHTML = statusCardHtml(body);
    }

    function showAttemptHeader() {
        var title = el('assessmentIntroTitle');
        var meta = el('assessmentIntroMeta');
        var counter = el('assessmentCounter');
        if (title) title.textContent = 'Final Assessment';
        if (meta) meta.textContent = 'Each answer is saved as you go and graded on submit.';
        if (counter) counter.textContent = 'Attempt ' + (statusInfo.attemptsToday + 1) + ' today';
    }

    function questionHtml(question, index) {
        var opts = (question.options || []).map(function (option, i) {
            var label = option.displayLabel || LETTERS[i];
            return '<label class="attempt-option">' +
                '<input type="radio" name="q' + (index + 1) + '" value="' + esc(option.optionId) + '">' +
                '<span class="opt-letter">' + esc(label) + '</span>' +
                esc(option.optionText) +
                '</label>';
        }).join('');

        return '<div class="quiz-attempt-question" data-qid="' + esc(question.questionId) + '">' +
            '<div class="attempt-question-text">' + (index + 1) + '. ' + esc(question.questionText) + '</div>' +
            '<div class="attempt-options">' + opts + '</div>' +
            '</div>';
    }

    function renderQuestions() {
        var target = el('assessmentQuestions');
        var submitRow = el('assessmentSubmitRow');
        if (!target) return;
        target.innerHTML = currentQuestions.map(questionHtml).join('');
        if (submitRow) submitRow.style.display = '';
        var resultBox = el('assessmentResult');
        if (resultBox) resultBox.innerHTML = '';
    }

    function startAssessment() {
        resultLocked = false;
        LearnovaFinalAssessmentApi.startAttempt(courseId).then(function (attemptResp) {
            attempt = attemptResp;
            currentQuestions = attempt.questions || [];
            selections = {};
            savedAnswers = {};
            var statusBox = el('assessmentStatus');
            if (statusBox) statusBox.innerHTML = '';
            renderQuestions();
            showAttemptHeader();
        }).catch(function (err) {
            resultLocked = false;
            LearnovaToast.error((err && err.message) || 'Could not start your final assessment.');
        });
    }

    function saveSelection(questionId, optionId) {
        LearnovaFinalAssessmentApi.saveAnswer(attempt.attemptId, questionId, optionId)
            .then(function () {
                savedAnswers[String(questionId)] = Number(optionId);
            })
            .catch(function (err) {
                LearnovaToast.error((err && err.message) || 'Could not save your answer.');
            });
    }

    function allAnswered() {
        return currentQuestions.every(function (q) {
            var key = String(q.questionId);
            var sel = selections[key];
            var saved = savedAnswers[key];
            return sel !== undefined && saved === sel;
        });
    }

    function disableInputs(disabled) {
        var inputs = document.querySelectorAll('#assessmentQuestions input');
        for (var i = 0; i < inputs.length; i++) {
            inputs[i].disabled = disabled;
        }
    }

    function renderHistory(rows) {
        var box = el('assessmentHistory');
        if (!box) return;

        if (!rows || !rows.length) {
            box.innerHTML = '<p class="flow-note">No final assessment attempts yet.</p>';
            return;
        }

        box.innerHTML =
            '<table class="history-table">' +
            '<thead><tr><th>Date</th><th>Score</th><th>Result</th></tr></thead>' +
            '<tbody>' +
            rows.map(function (r) {
                return '<tr>' +
                    '<td>' + esc(formatDate(r.submitted_at)) + '</td>' +
                    '<td>' + esc(r.score_pct) + '%</td>' +
                    '<td class="' + (r.passed ? 'badge-pass' : 'badge-fail') + '">' +
                        (r.passed ? 'Passed' : 'Failed') +
                    '</td>' +
                    '</tr>';
            }).join('') +
            '</tbody></table>';
    }

    function refreshHistory() {
        if (!courseId) return Promise.resolve();
        return LearnovaFinalAssessmentApi.history(courseId)
            .then(function (rows) { renderHistory(rows || []); })
            .catch(function () { renderHistory([]); });
    }

    function refreshAfterSubmit() {
        return LearnovaFinalAssessmentApi.status(courseId).then(function (s) {
            statusInfo = s || {};
            setIntro();
            return refreshHistory();
        }).catch(function () {
            return refreshHistory();
        });
    }

    function showResult(result) {
        var resultBox = el('assessmentResult');
        if (!resultBox) return;

        var score = (result && result.scorePct !== undefined) ? result.scorePct : 0;
        var passed = Boolean(result && result.passed);
        var remaining = statusInfo.remainingAttempts || 0;

        if (passed) {
            resultBox.innerHTML =
                '<div class="quiz-result pass">' +
                '<div class="quiz-result-score">Score: ' + score + '% — Passed</div>' +
                '<p>You passed the ' + (statusInfo.passingScore || 0) +
                '% threshold. Your course is now complete and the certificate has been issued.</p>' +
                '<div class="assessment-stats">' +
                    '<a class="btn btn-primary" href="certificates.html">View Certificates</a>' +
                    '<a class="btn btn-outline" href="' + esc(backToCourse()) + '">Back to Course</a>' +
                '</div>' +
                '</div>';
        } else {
            resultBox.innerHTML =
                '<div class="quiz-result fail">' +
                '<div class="quiz-result-score">Score: ' + score + '% — Not passed</div>' +
                '<p>Below the ' + (statusInfo.passingScore || 0) + '% passing score. ' +
                (remaining > 0
                    ? 'Attempts left today: ' + remaining + ' (resets at midnight).'
                    : 'You have no attempts left today — try again at midnight.') +
                '</p>' +
                (remaining > 0
                    ? '<button class="btn btn-outline" id="retryBtn" type="button">Try Again</button>'
                    : '<a class="btn btn-outline" href="' + esc(backToCourse()) + '">Back to Course</a>') +
                '</div>';
        }
    }

    document.addEventListener('click', function (event) {
        var option = event.target.closest('.attempt-option');
        if (option && !resultLocked) {
            var input = option.querySelector('input');
            if (input && !input.disabled) {
                var group = option.parentNode;
                var name = input.name;
                var radios = group.querySelectorAll('input[type="radio"][name="' + name + '"]');
                for (var i = 0; i < radios.length; i++) {
                    radios[i].checked = false;
                    radios[i].closest('.attempt-option').classList.remove('selected');
                }
                input.checked = true;
                option.classList.add('selected');

                var card = option.closest('[data-qid]');
                var qid = card ? card.getAttribute('data-qid') : null;
                if (qid && input.value !== undefined && input.value !== '') {
                    var optId = Number(input.value);
                    selections[String(qid)] = optId;
                    saveSelection(Number(qid), optId);
                }
            }
        }

        if (event.target.closest('#retryBtn')) startAssessment();
        if (event.target.closest('#startBtn')) startAssessment();
    });

    var submitBtn = el('submitBtn');
    if (submitBtn) {
        submitBtn.addEventListener('click', function () {
            if (resultLocked || !currentQuestions.length) return;

            if (!allAnswered()) {
                LearnovaToast.error('Answer all ' + currentQuestions.length +
                    ' questions (and wait for each answer to save) before submitting.');
                return;
            }

            resultLocked = true;
            disableInputs(true);
            LearnovaFinalAssessmentApi.submit(attempt.attemptId).then(function (result) {
                return refreshAfterSubmit().then(function () {
                    showResult(result);
                });
            }).catch(function (err) {
                resultLocked = false;
                disableInputs(false);
                LearnovaToast.error((err && err.message) || 'Could not submit your assessment.');
            });
        });
    }

    var clearBtn = el('clearBtn');
    if (clearBtn) {
        clearBtn.addEventListener('click', function () {
            if (resultLocked) return;
            var options = document.querySelectorAll('#assessmentQuestions .attempt-option');
            for (var i = 0; i < options.length; i++) {
                options[i].classList.remove('selected');
                options[i].querySelector('input').checked = false;
            }
            selections = {};
            savedAnswers = {};
        });
    }

    function failLoad(message) {
        var box = el('assessmentStatus');
        if (box) {
            box.innerHTML = statusCardHtml(
                '<h2>Could not load assessment</h2>' +
                '<p>' + esc(message || 'Invalid course.') + '</p>'
            );
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        resolveCourseId(rawCourse).then(function (id) {
            courseId = id;
            if (!Number.isInteger(courseId) || courseId < 1) {
                failLoad();
                return;
            }

            return Promise.all([
                LearnovaCourseApi.get(courseId).catch(function () { return null; }),
                LearnovaFinalAssessmentApi.status(courseId)
            ]).then(function (results) {
                course = results[0];
                statusInfo = results[1] || {};
                setIntro();
                renderStatus();
                return refreshHistory();
            });
        }).catch(function (err) {
            failLoad((err && err.message) || 'Could not load your final assessment.');
        });
    });
})();