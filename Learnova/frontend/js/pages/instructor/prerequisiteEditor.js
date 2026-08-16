/* ==========================================================================
   Learnova Instructor Prerequisite Editor
   --------------------------------------------------------------------------
   URL:

       prerequisite-editor.html?course=<numeric course id>

   Network contract:

       page load
           → ONE GET

       save
           → ONE PUT

   No course catalogue download.
   No slug lookup.
   No add/remove HTTP loops.

   PostgreSQL remains the final authority for:
       - ownership
       - editable lifecycle
       - valid prerequisite candidates
       - score rules
       - duplicate edges
       - cycles
       - maximum chain depth
   ========================================================================== */

(function () {
    'use strict';


    /* ======================================================================
       Bootstrap
       ====================================================================== */

    var params =
        new URLSearchParams(
            window.location.search
        );


    var rawCourseId =
        String(
            params.get('course') || ''
        ).trim();


    var courseId =
        /^\d+$/.test(rawCourseId) &&
            Number(rawCourseId) > 0

            ? Number(rawCourseId)

            : null;


    var root =
        document.getElementById(
            'prerequisitePage'
        );


    var backLink =
        document.getElementById(
            'backToCourseEditor'
        );


    if (!root) {
        return;
    }


    if (courseId && backLink) {

        backLink.href =
            'course-editor.html?course=' +
            encodeURIComponent(
                courseId
            );
    }


    /* ======================================================================
       State
       ====================================================================== */

    var state = {
        targetCourseId: courseId,

        targetTitle: '',

        targetSlug: '',

        targetStatus: '',

        editable: false,

        prerequisites: [],

        candidates: [],

        loading: false,

        saving: false
    };


    /* ======================================================================
       Helpers
       ====================================================================== */

    function showToast(
        message,
        type
    ) {

        if (
            window.LearnovaToast &&
            typeof LearnovaToast[type] ===
            'function'
        ) {

            LearnovaToast[type](
                message
            );

            return;
        }


        console[
            type === 'error'
                ? 'error'
                : 'log'
        ](
            message
        );
    }


    function normalizeStatus(value) {

        var status =
            String(value || '')
                .trim()
                .toLowerCase();


        if (!status) {
            return 'unknown';
        }


        return status;
    }


    function statusLabel(value) {

        return normalizeStatus(value)
            .replace(/[_-]+/g, ' ')
            .replace(
                /\b\w/g,
                function (character) {
                    return character
                        .toUpperCase();
                }
            );
    }


    function normalizeScore(value) {

        var score =
            Number(value);


        if (!Number.isFinite(score)) {
            return null;
        }


        return score;
    }


    function createElement(
        tagName,
        className,
        text
    ) {

        var node =
            document.createElement(
                tagName
            );


        if (className) {
            node.className =
                className;
        }


        if (
            text !== undefined &&
            text !== null
        ) {
            node.textContent =
                text;
        }


        return node;
    }


    function clear(node) {

        while (node.firstChild) {

            node.removeChild(
                node.firstChild
            );
        }
    }


    function candidateById(
        candidateId
    ) {

        return state.candidates.find(
            function (candidate) {

                return Number(
                    candidate.courseId
                ) === Number(
                    candidateId
                );
            }
        );
    }


    function sortCourses(list) {

        return list.sort(
            function (left, right) {

                return String(
                    left.title || ''
                ).localeCompare(
                    String(
                        right.title || ''
                    ),
                    undefined,
                    {
                        sensitivity: 'base'
                    }
                );
            }
        );
    }


    /* ======================================================================
       Invalid URL
       ====================================================================== */

    function renderInvalidCourse() {

        clear(root);


        var card =
            createElement(
                'div',
                'card prerequisite-error'
            );


        card.appendChild(
            createElement(
                'i',
                'fa-solid fa-triangle-exclamation'
            )
        );


        card.appendChild(
            createElement(
                'h2',
                '',
                'A valid course is required'
            )
        );


        card.appendChild(
            createElement(
                'p',
                '',
                'Open Prerequisites from a specific course editor.'
            )
        );


        var link =
            createElement(
                'a',
                'btn btn-primary',
                'Back to Courses'
            );


        link.href =
            'courses.html';

        link.style.marginTop =
            '1rem';


        card.appendChild(link);

        root.appendChild(card);
    }


    /* ======================================================================
       Loading
       ====================================================================== */

    function renderLoading() {

        clear(root);


        var card =
            createElement(
                'div',
                'card prerequisite-loading'
            );


        card.appendChild(
            createElement(
                'i',
                'fa-solid fa-arrows-rotate'
            )
        );


        card.appendChild(
            createElement(
                'p',
                '',
                'Loading prerequisite settings...'
            )
        );


        root.appendChild(card);
    }


    /* ======================================================================
       Error
       ====================================================================== */

    function renderError(error) {

        clear(root);


        var card =
            createElement(
                'div',
                'card prerequisite-error'
            );


        card.appendChild(
            createElement(
                'i',
                'fa-solid fa-triangle-exclamation'
            )
        );


        card.appendChild(
            createElement(
                'h2',
                '',
                'Could not load prerequisites'
            )
        );


        card.appendChild(
            createElement(
                'p',
                '',
                error &&
                    error.message

                    ? error.message

                    : 'The prerequisite editor request failed.'
            )
        );


        var retry =
            createElement(
                'button',
                'btn btn-primary',
                'Try Again'
            );


        retry.type =
            'button';

        retry.dataset.action =
            'retry-load';

        retry.style.marginTop =
            '1rem';


        card.appendChild(retry);

        root.appendChild(card);
    }


    /* ======================================================================
       Target panel
       ====================================================================== */

    function createTargetPanel() {

        var panel =
            createElement(
                'section',
                'card editor-panel'
            );


        panel.appendChild(
            createElement(
                'h3',
                '',
                'Target Course'
            )
        );


        panel.appendChild(
            createElement(
                'p',
                'prerequisite-target-title',
                state.targetTitle ||
                'Course'
            )
        );


        var meta =
            createElement(
                'p',
                'prerequisite-target-meta'
            );


        meta.textContent =
            'Course ID: ' +
            state.targetCourseId;


        panel.appendChild(meta);


        var status =
            createElement(
                'span',
                'prerequisite-status-pill'
            );


        var statusIcon =
            createElement(
                'i',
                state.editable

                    ? 'fa-solid fa-pen'

                    : 'fa-solid fa-lock'
            );


        status.appendChild(
            statusIcon
        );


        status.appendChild(
            document.createTextNode(
                ' ' +
                statusLabel(
                    state.targetStatus
                )
            )
        );


        panel.appendChild(status);


        var explanation =
            createElement(
                'div',
                'quiz-banner'
            );


        explanation.style.marginTop =
            '1.3rem';


        var explanationTitle =
            createElement(
                'span',
                'banner-title',
                'AND prerequisite rule: '
            );


        explanation.appendChild(
            explanationTitle
        );


        explanation.appendChild(
            document.createTextNode(
                'students must satisfy every prerequisite course before enrollment is allowed.'
            )
        );


        panel.appendChild(
            explanation
        );


        if (!state.editable) {

            var readonly =
                createElement(
                    'div',
                    'prerequisite-readonly'
                );


            readonly.appendChild(
                createElement(
                    'i',
                    'fa-solid fa-lock'
                )
            );


            readonly.appendChild(
                document.createTextNode(
                    ' This course is currently read-only. Prerequisites can only be changed during an editable course lifecycle state.'
                )
            );


            panel.appendChild(
                readonly
            );
        }


        return panel;
    }


    /* ======================================================================
       Candidate selector
       ====================================================================== */

    function createCandidateSelect() {

        var select =
            document.createElement(
                'select'
            );


        select.id =
            'prerequisiteCandidate';


        var placeholder =
            document.createElement(
                'option'
            );


        placeholder.value =
            '';

        placeholder.textContent =
            state.candidates.length

                ? 'Choose a course...'

                : 'No available courses';


        select.appendChild(
            placeholder
        );


        sortCourses(
            state.candidates.slice()
        )
            .forEach(
                function (candidate) {

                    var option =
                        document.createElement(
                            'option'
                        );


                    option.value =
                        String(
                            candidate.courseId
                        );


                    option.textContent =
                        candidate.title +
                        ' · ' +
                        statusLabel(
                            candidate.status
                        );


                    select.appendChild(
                        option
                    );
                }
            );


        select.disabled =
            !state.editable ||
            !state.candidates.length;


        return select;
    }


    /* ======================================================================
       Current prerequisite item
       ====================================================================== */

    function createPrerequisiteItem(
        prerequisite
    ) {

        var row =
            createElement(
                'div',
                'prerequisite-editor-item'
            );


        row.dataset.courseId =
            String(
                prerequisite.courseId
            );


        /* ------------------------------------------------------
           Course identity
           ------------------------------------------------------ */

        var identity =
            document.createElement(
                'div'
            );


        identity.appendChild(
            createElement(
                'div',
                'prerequisite-course-name',
                prerequisite.title ||
                'Untitled Course'
            )
        );


        identity.appendChild(
            createElement(
                'div',
                'prerequisite-course-meta',
                statusLabel(
                    prerequisite.status
                ) +
                ' · Course ' +
                prerequisite.courseId
            )
        );


        /* ------------------------------------------------------
           Minimum score
           ------------------------------------------------------ */

        var scoreArea =
            document.createElement(
                'div'
            );


        var scoreLabel =
            createElement(
                'label',
                'prerequisite-score-label',
                'Minimum score (%)'
            );


        var scoreInput =
            document.createElement(
                'input'
            );


        scoreInput.type =
            'number';

        scoreInput.className =
            'prerequisite-score-input';

        scoreInput.min =
            '0';

        scoreInput.max =
            '100';

        scoreInput.step =
            '0.01';


        scoreInput.value =
            prerequisite.requiredMinScore ===
                null ||
                prerequisite.requiredMinScore ===
                undefined

                ? '60'

                : String(
                    prerequisite.requiredMinScore
                );


        scoreInput.dataset.scoreFor =
            String(
                prerequisite.courseId
            );


        scoreInput.disabled =
            !state.editable;


        scoreArea.appendChild(
            scoreLabel
        );

        scoreArea.appendChild(
            scoreInput
        );


        /* ------------------------------------------------------
           Remove
           ------------------------------------------------------ */

        var remove =
            createElement(
                'button',
                'prerequisite-remove'
            );


        remove.type =
            'button';

        remove.dataset.action =
            'remove-prerequisite';

        remove.dataset.courseId =
            String(
                prerequisite.courseId
            );


        remove.setAttribute(
            'aria-label',
            'Remove ' +
            (
                prerequisite.title ||
                'prerequisite'
            )
        );


        remove.disabled =
            !state.editable;


        remove.appendChild(
            createElement(
                'i',
                'fa-solid fa-trash'
            )
        );


        row.appendChild(identity);

        row.appendChild(
            scoreArea
        );

        row.appendChild(
            remove
        );


        return row;
    }


    /* ======================================================================
       Prerequisite panel
       ====================================================================== */

    function createEditorPanel() {

        var panel =
            createElement(
                'section',
                'card editor-panel'
            );


        panel.appendChild(
            createElement(
                'h3',
                '',
                'Prerequisite Courses'
            )
        );


        var description =
            createElement(
                'p',
                '',
                'Each prerequisite may require its own minimum completion score. The default is 60%.'
            );


        description.style.color =
            '#5f5f7a';

        description.style.fontSize =
            '1.1rem';

        description.style.marginBottom =
            '1.2rem';


        panel.appendChild(
            description
        );


        /* ------------------------------------------------------
           Add row
           ------------------------------------------------------ */

        var addRow =
            createElement(
                'div',
                'prerequisite-add-row'
            );


        var courseField =
            createElement(
                'div',
                'form-field'
            );


        var courseLabel =
            document.createElement(
                'label'
            );


        courseLabel.htmlFor =
            'prerequisiteCandidate';

        courseLabel.textContent =
            'Add prerequisite';


        courseField.appendChild(
            courseLabel
        );


        courseField.appendChild(
            createCandidateSelect()
        );


        var scoreField =
            createElement(
                'div',
                'form-field'
            );


        var scoreLabel =
            document.createElement(
                'label'
            );


        scoreLabel.htmlFor =
            'newPrerequisiteScore';

        scoreLabel.textContent =
            'Minimum score';


        var scoreInput =
            document.createElement(
                'input'
            );


        scoreInput.id =
            'newPrerequisiteScore';

        scoreInput.type =
            'number';

        scoreInput.min =
            '0';

        scoreInput.max =
            '100';

        scoreInput.step =
            '0.01';

        scoreInput.value =
            '60';

        scoreInput.disabled =
            !state.editable;


        scoreField.appendChild(
            scoreLabel
        );

        scoreField.appendChild(
            scoreInput
        );


        var addButton =
            createElement(
                'button',
                'btn btn-primary',
                'Add'
            );


        addButton.type =
            'button';

        addButton.dataset.action =
            'add-prerequisite';

        addButton.disabled =
            !state.editable ||
            !state.candidates.length;


        addRow.appendChild(
            courseField
        );

        addRow.appendChild(
            scoreField
        );

        addRow.appendChild(
            addButton
        );


        panel.appendChild(
            addRow
        );


        /* ------------------------------------------------------
           Current list
           ------------------------------------------------------ */

        var list =
            createElement(
                'div',
                'prerequisite-editor-list'
            );


        list.id =
            'prerequisiteList';


        if (!state.prerequisites.length) {

            list.appendChild(
                createElement(
                    'div',
                    'blocks-empty',
                    'No prerequisites. Students may enroll without completing another course first.'
                )
            );

        } else {

            sortCourses(
                state.prerequisites.slice()
            )
                .forEach(
                    function (prerequisite) {

                        list.appendChild(
                            createPrerequisiteItem(
                                prerequisite
                            )
                        );
                    }
                );
        }


        panel.appendChild(list);


        /* ------------------------------------------------------
           Save
           ------------------------------------------------------ */

        var saveRow =
            createElement(
                'div',
                'prerequisite-save-row'
            );


        var save =
            createElement(
                'button',
                'btn btn-primary',
                state.saving
                    ? 'Saving...'
                    : 'Save Prerequisites'
            );


        save.type =
            'button';

        save.id =
            'savePrerequisites';

        save.dataset.action =
            'save-prerequisites';

        save.disabled =
            !state.editable ||
            state.saving;


        saveRow.appendChild(save);

        panel.appendChild(saveRow);


        return panel;
    }


    /* ======================================================================
       Main render
       ====================================================================== */

    function render() {

        clear(root);


        var layout =
            createElement(
                'div',
                'prerequisite-layout'
            );


        layout.appendChild(
            createTargetPanel()
        );


        layout.appendChild(
            createEditorPanel()
        );


        root.appendChild(layout);
    }


    /* ======================================================================
       Apply server response
       ====================================================================== */

    function applyEditor(editor) {

        state.targetCourseId =
            Number(
                editor.targetCourseId
            );


        state.targetTitle =
            editor.targetTitle || '';


        state.targetSlug =
            editor.targetSlug || '';


        state.targetStatus =
            editor.targetStatus || '';


        state.editable =
            Boolean(
                editor.editable
            );


        state.prerequisites =
            Array.isArray(
                editor.prerequisites
            )

                ? editor.prerequisites.slice()

                : [];


        state.candidates =
            Array.isArray(
                editor.candidates
            )

                ? editor.candidates.slice()

                : [];


        state.saving =
            false;


        render();
    }


    /* ======================================================================
       Load
       ====================================================================== */

    function load() {

        if (!courseId) {

            renderInvalidCourse();

            return;
        }


        state.loading =
            true;


        renderLoading();


        LearnovaPrerequisiteApi
            .getEditor(
                courseId
            )

            .then(
                function (editor) {

                    state.loading =
                        false;


                    applyEditor(
                        editor || {}
                    );
                }
            )

            .catch(
                function (error) {

                    state.loading =
                        false;


                    renderError(
                        error
                    );
                }
            );
    }


    /* ======================================================================
       Add prerequisite locally
       ====================================================================== */

    function addPrerequisite() {

        if (!state.editable) {
            return;
        }


        var select =
            document.getElementById(
                'prerequisiteCandidate'
            );


        var scoreInput =
            document.getElementById(
                'newPrerequisiteScore'
            );


        if (
            !select ||
            !select.value
        ) {

            showToast(
                'Choose a prerequisite course.',
                'error'
            );

            return;
        }


        var candidateId =
            Number(
                select.value
            );


        var candidate =
            candidateById(
                candidateId
            );


        if (!candidate) {

            showToast(
                'That prerequisite course is no longer available.',
                'error'
            );

            return;
        }


        var score =
            normalizeScore(
                scoreInput
                    ? scoreInput.value
                    : 60
            );


        if (score === null) {

            showToast(
                'Enter a valid minimum score.',
                'error'
            );

            return;
        }


        state.prerequisites.push({
            courseId:
                candidate.courseId,

            title:
                candidate.title,

            slug:
                candidate.slug,

            status:
                candidate.status,

            requiredMinScore:
                score
        });


        state.candidates =
            state.candidates.filter(
                function (item) {

                    return Number(
                        item.courseId
                    ) !== candidateId;
                }
            );


        render();
    }


    /* ======================================================================
       Remove prerequisite locally
       ====================================================================== */

    function removePrerequisite(
        prerequisiteId
    ) {

        if (!state.editable) {
            return;
        }


        var removed =
            state.prerequisites.find(
                function (item) {

                    return Number(
                        item.courseId
                    ) === Number(
                        prerequisiteId
                    );
                }
            );


        if (!removed) {
            return;
        }


        state.prerequisites =
            state.prerequisites.filter(
                function (item) {

                    return Number(
                        item.courseId
                    ) !== Number(
                        prerequisiteId
                    );
                }
            );


        state.candidates.push({
            courseId:
                removed.courseId,

            title:
                removed.title,

            slug:
                removed.slug,

            status:
                removed.status
        });


        render();
    }


    /* ======================================================================
       Collect scores
       ====================================================================== */

    function collectPayload() {

        var payload = [];


        for (
            var index = 0;
            index < state.prerequisites.length;
            index += 1
        ) {

            var prerequisite =
                state.prerequisites[index];


            var input =
                document.querySelector(
                    '[data-score-for="' +
                    prerequisite.courseId +
                    '"]'
                );


            var score =
                normalizeScore(
                    input
                        ? input.value
                        : prerequisite.requiredMinScore
                );


            if (score === null) {

                showToast(
                    'Enter a valid minimum score for ' +
                    (
                        prerequisite.title ||
                        'each prerequisite'
                    ) +
                    '.',
                    'error'
                );


                if (input) {
                    input.focus();
                }


                return null;
            }


            payload.push({
                prerequisiteCourseId:
                    Number(
                        prerequisite.courseId
                    ),

                requiredMinScore:
                    score
            });
        }


        return payload;
    }


    /* ======================================================================
       Save
       ====================================================================== */

    function save() {

        if (
            !state.editable ||
            state.saving
        ) {
            return;
        }


        var payload =
            collectPayload();


        if (payload === null) {
            return;
        }


        state.saving =
            true;


        var button =
            document.getElementById(
                'savePrerequisites'
            );


        if (button) {

            button.disabled =
                true;

            button.textContent =
                'Saving...';
        }


        LearnovaPrerequisiteApi
            .replace(
                courseId,
                payload
            )

            .then(
                function (editor) {

                    applyEditor(
                        editor || {}
                    );


                    showToast(
                        'Prerequisites saved.',
                        'success'
                    );
                }
            )

            .catch(
                function (error) {

                    state.saving =
                        false;


                    if (button) {

                        button.disabled =
                            false;

                        button.textContent =
                            'Save Prerequisites';
                    }


                    showToast(
                        error &&
                            error.message

                            ? error.message

                            : 'Could not save prerequisites.',
                        'error'
                    );
                }
            );
    }


    /* ======================================================================
       Events
       ====================================================================== */

    document.addEventListener(
        'click',
        function (event) {

            var action =
                event.target.closest(
                    '[data-action]'
                );


            if (!action) {
                return;
            }


            var actionName =
                action.dataset.action;


            if (
                actionName ===
                'retry-load'
            ) {

                load();

                return;
            }


            if (
                actionName ===
                'add-prerequisite'
            ) {

                addPrerequisite();

                return;
            }


            if (
                actionName ===
                'remove-prerequisite'
            ) {

                removePrerequisite(
                    Number(
                        action.dataset.courseId
                    )
                );

                return;
            }


            if (
                actionName ===
                'save-prerequisites'
            ) {

                save();
            }
        }
    );


    /* ======================================================================
       Start
       ====================================================================== */
    if (!courseId) {

        renderInvalidCourse();
    } else {

        load();
    }
})();