/* ==========================================================================
   Learnova Instructor Course Editor
   --------------------------------------------------------------------------
   URL:

       course-editor.html?course=<numeric id>

   Responsibilities:
       - edit course settings
       - edit curriculum
       - navigate to prerequisite editor
       - navigate to lesson content/quiz editors

   PostgreSQL owns all course lifecycle/business-rule validation.
   ========================================================================== */

(function () {
    'use strict';


    /* ======================================================================
       Course identity
       ====================================================================== */

    var params =
        new URLSearchParams(
            window.location.search
        );


    var courseParam =
        params.get('course');


    var courseId =
        /^\d+$/.test(
            String(
                courseParam || ''
            ).trim()
        )

            ? String(
                courseParam
            ).trim()

            : null;


    var state = {
        modules: [],
        thumbnailUrl: null,
        shortDescription: ''
    };


    if (!courseId) {

        window.location.replace(
            'courses.html'
        );

        return;
    }


    /* ======================================================================
       Helpers
       ====================================================================== */

    function escapeHtml(text) {

        return String(
            text === null ||
            text === undefined

                ? ''

                : text
        )
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }


    function toast(message) {

        if (
            window.LearnovaToast &&
            typeof LearnovaToast.success ===
                'function'
        ) {

            LearnovaToast.success(
                message
            );

            return;
        }


        var note =
            document.createElement(
                'div'
            );


        note.className =
            'course-toast';


        note.textContent =
            message;


        document.body.appendChild(
            note
        );


        setTimeout(
            function () {

                if (note.parentNode) {

                    note.parentNode.removeChild(
                        note
                    );
                }
            },
            2600
        );
    }


    function errorToast(message) {

        if (
            window.LearnovaToast &&
            typeof LearnovaToast.error ===
                'function'
        ) {

            LearnovaToast.error(
                message
            );

            return;
        }


        toast(
            message
        );
    }


    /* ======================================================================
       Related authoring links
       ====================================================================== */

    function initializeAuthoringLinks() {

        var prerequisitesLink =
            document.getElementById(
                'prerequisitesLink'
            );


        if (prerequisitesLink) {

            prerequisitesLink.href =
                'prerequisite-editor.html?course=' +
                encodeURIComponent(
                    courseId
                );
        }
    }


    /* ======================================================================
       Curriculum mapping
       ====================================================================== */

    function toBackendCurriculum() {

        return {

            modules:
                state.modules.map(
                    function (module) {

                        return {

                            title:
                                module.title,

                            description:
                                module.description ||
                                null,

                            lessons:
                                (
                                    module.lessons ||
                                    []
                                )
                                    .map(
                                        function (lesson) {

                                            return {
                                                title:
                                                    lesson.name
                                            };
                                        }
                                    )
                        };
                    }
                )
        };
    }


    /* ======================================================================
       Course settings
       ====================================================================== */

    function populateSettings(course) {

        var title =
            document.getElementById(
                'courseTitle'
            );


        var description =
            document.getElementById(
                'courseDescription'
            );


        if (title) {

            title.value =
                course.title || '';
        }


        if (description) {

            description.value =
                course.description ||
                course.shortDescription ||
                '';
        }


        state.shortDescription =
            course.shortDescription ||
            course.description ||
            '';


        state.thumbnailUrl =
            course.thumbnailUrl ||
            null;


        var category =
            document.getElementById(
                'courseCategory'
            );


        if (
            category &&
            course.categoryId
        ) {

            category.value =
                String(
                    course.categoryId
                );
        }


        var difficulty =
            document.getElementById(
                'courseDifficulty'
            );


        if (
            difficulty &&
            course.difficulty
        ) {

            difficulty.value =
                String(
                    course.difficulty
                ).toLowerCase();
        }
    }


    function loadSettings() {

        return LearnovaInstructorApi
            .getCourse(
                courseId
            )

            .then(
                populateSettings
            )

            .catch(
                function (error) {

                    errorToast(
                        error &&
                        error.message

                            ? error.message

                            : 'Could not load course settings.'
                    );
                }
            );
    }


    function loadCategories() {

        return LearnovaCourseApi
            .getCategories()

            .then(
                function (categories) {

                    var select =
                        document.getElementById(
                            'courseCategory'
                        );


                    if (!select) {
                        return;
                    }


                    select.innerHTML =
                        '';


                    var empty =
                        document.createElement(
                            'option'
                        );


                    empty.value =
                        '';

                    empty.textContent =
                        'No category';


                    select.appendChild(
                        empty
                    );


                    (
                        Array.isArray(
                            categories
                        )
                            ? categories
                            : []
                    )
                        .forEach(
                            function (category) {

                                var option =
                                    document.createElement(
                                        'option'
                                    );


                                option.value =
                                    String(
                                        category.id
                                    );


                                option.textContent =
                                    category.name ||
                                    'Unnamed category';


                                select.appendChild(
                                    option
                                );
                            }
                        );
                }
            )

            .catch(
                function () {

                    var select =
                        document.getElementById(
                            'courseCategory'
                        );


                    if (select) {

                        select.innerHTML =
                            '<option value="">' +
                            'Categories unavailable' +
                            '</option>';
                    }
                }
            );
    }


    /* ======================================================================
       Curriculum
       ====================================================================== */

    function loadCurriculum() {

        return LearnovaInstructorApi
            .getCurriculum(
                courseId
            )

            .then(
                function (curriculum) {

                    state.modules =
                        (
                            curriculum &&
                            Array.isArray(
                                curriculum.modules
                            )

                                ? curriculum.modules

                                : []
                        )
                            .map(
                                function (module) {

                                    return {

                                        moduleId:
                                            module.moduleId,

                                        title:
                                            module.title,

                                        description:
                                            module.description ||
                                            null,

                                        lessons:
                                            (
                                                module.lessons ||
                                                []
                                            )
                                                .map(
                                                    function (lesson) {

                                                        return {

                                                            lessonId:
                                                                lesson.lessonId,

                                                            name:
                                                                lesson.title
                                                        };
                                                    }
                                                )
                                    };
                                }
                            );


                    renderCurriculum();
                }
            )

            .catch(
                function (error) {

                    state.modules =
                        [];


                    renderCurriculum();


                    errorToast(
                        error &&
                        error.message

                            ? error.message

                            : 'Could not load curriculum.'
                    );
                }
            );
    }


    function saveCurriculum() {

        return LearnovaInstructorApi
            .setCurriculum(
                courseId,
                toBackendCurriculum()
            );
    }


    function renderCurriculum() {

        var container =
            document.getElementById(
                'curriculum'
            );


        if (!container) {
            return;
        }


        if (!state.modules.length) {

            container.innerHTML =

                '<div class="blocks-empty">' +
                    'No modules yet. Add your first module and start building lessons.' +
                '</div>';


            return;
        }


        container.innerHTML =
            state.modules
                .map(
                    function (
                        module,
                        moduleIndex
                    ) {

                        var lessons =
                            (
                                module.lessons ||
                                []
                            )
                                .map(
                                    function (
                                        lesson,
                                        lessonIndex
                                    ) {

                                        var lessonKey =
                                            encodeURIComponent(
                                                lesson.name
                                            );


                                        return (

                                            '<div class="lesson-block">' +

                                                '<span class="lesson-name">' +
                                                    escapeHtml(
                                                        lesson.name
                                                    ) +
                                                '</span>' +

                                                '<div class="lesson-actions">' +

                                                    '<a ' +
                                                        'class="quiz-link" ' +
                                                        'href="lesson-editor.html?course=' +
                                                        encodeURIComponent(
                                                            courseId
                                                        ) +
                                                        '&lesson=' +
                                                        lessonKey +
                                                        '">' +
                                                        'Edit Content' +
                                                    '</a>' +

                                                    '<a ' +
                                                        'class="quiz-link" ' +
                                                        'href="quiz-editor.html?course=' +
                                                        encodeURIComponent(
                                                            courseId
                                                        ) +
                                                        '&lesson=' +
                                                        lessonKey +
                                                        '">' +
                                                        'Quiz (20 MCQ)' +
                                                    '</a>' +

                                                    '<button ' +
                                                        'class="btn btn-danger btn-sm" ' +
                                                        'type="button" ' +
                                                        'data-action="delete-lesson" ' +
                                                        'data-m="' +
                                                        moduleIndex +
                                                        '" ' +
                                                        'data-l="' +
                                                        lessonIndex +
                                                        '">' +

                                                        '<i class="fa-solid fa-trash"></i>' +

                                                    '</button>' +

                                                '</div>' +

                                            '</div>'
                                        );
                                    }
                                )
                                .join('');


                        return (

                            '<div ' +
                                'class="module-block" ' +
                                'data-module="' +
                                (
                                    moduleIndex +
                                    1
                                ) +
                                '">' +

                                '<div class="module-head">' +

                                    '<span class="module-title">' +
                                        escapeHtml(
                                            module.title ||
                                            (
                                                'Module ' +
                                                (
                                                    moduleIndex +
                                                    1
                                                )
                                            )
                                        ) +
                                    '</span>' +

                                    '<div class="lesson-actions">' +

                                        '<button ' +
                                            'class="btn btn-danger btn-sm" ' +
                                            'type="button" ' +
                                            'data-action="delete-module" ' +
                                            'data-m="' +
                                            moduleIndex +
                                            '">' +

                                            'Delete Module' +

                                        '</button>' +

                                    '</div>' +

                                '</div>' +

                                '<div class="module-lessons">' +

                                    (
                                        lessons ||
                                        '<span class="meta-item">' +
                                            'No lessons yet.' +
                                        '</span>'
                                    ) +

                                '</div>' +

                                '<button ' +
                                    'class="btn-add-sm" ' +
                                    'style="margin-top: 1rem;" ' +
                                    'type="button" ' +
                                    'data-action="add-lesson" ' +
                                    'data-m="' +
                                    moduleIndex +
                                    '">' +

                                    '+ Add Lesson to this Module' +

                                '</button>' +

                            '</div>'
                        );
                    }
                )
                .join('');
    }


    /* ======================================================================
       Curriculum mutations
       ====================================================================== */

    function addModule() {

        return LearnovaPrompt
            .ask(
                'Enter module title:',
                {
                    title:
                        'New Module',

                    defaultValue:
                        'Module ' +
                        (
                            state.modules.length +
                            1
                        )
                }
            )

            .then(
                function (name) {

                    if (
                        !name ||
                        !name.trim()
                    ) {
                        return;
                    }


                    state.modules.push({
                        title:
                            name.trim(),

                        description:
                            null,

                        lessons:
                            []
                    });


                    return saveCurriculum()
                        .then(
                            renderCurriculum
                        )

                        .catch(
                            function (error) {

                                state.modules.pop();


                                errorToast(
                                    error &&
                                    error.message

                                        ? error.message

                                        : 'Could not save module.'
                                );
                            }
                        );
                }
            );
    }


    function deleteModule(
        moduleIndex
    ) {

        return LearnovaConfirm
            .ask(
                'Delete this module and all of its lessons?'
            )

            .then(
                function (confirmed) {

                    if (!confirmed) {
                        return;
                    }


                    var removed =
                        state.modules.splice(
                            moduleIndex,
                            1
                        );


                    return saveCurriculum()
                        .then(
                            renderCurriculum
                        )

                        .catch(
                            function (error) {

                                state.modules.splice(
                                    moduleIndex,
                                    0,
                                    removed[0]
                                );


                                errorToast(
                                    error &&
                                    error.message

                                        ? error.message

                                        : 'Could not delete module.'
                                );
                            }
                        );
                }
            );
    }


    function addLesson(
        moduleIndex
    ) {

        return LearnovaPrompt
            .ask(
                'Enter lesson name:',
                {
                    title:
                        'New Lesson',

                    defaultValue:
                        'Lesson ' +
                        (
                            state.modules[
                                moduleIndex
                            ].lessons.length +
                            1
                        )
                }
            )

            .then(
                function (name) {

                    if (
                        !name ||
                        !name.trim()
                    ) {
                        return;
                    }


                    state.modules[
                        moduleIndex
                    ].lessons.push({
                        name:
                            name.trim()
                    });


                    return saveCurriculum()
                        .then(
                            renderCurriculum
                        )

                        .catch(
                            function (error) {

                                state.modules[
                                    moduleIndex
                                ].lessons.pop();


                                errorToast(
                                    error &&
                                    error.message

                                        ? error.message

                                        : 'Could not save lesson.'
                                );
                            }
                        );
                }
            );
    }


    function deleteLesson(
        moduleIndex,
        lessonIndex
    ) {

        return LearnovaConfirm
            .ask(
                'Delete this lesson?'
            )

            .then(
                function (confirmed) {

                    if (!confirmed) {
                        return;
                    }


                    var removed =
                        state.modules[
                            moduleIndex
                        ].lessons.splice(
                            lessonIndex,
                            1
                        );


                    return saveCurriculum()
                        .then(
                            renderCurriculum
                        )

                        .catch(
                            function (error) {

                                state.modules[
                                    moduleIndex
                                ].lessons.splice(
                                    lessonIndex,
                                    0,
                                    removed[0]
                                );


                                errorToast(
                                    error &&
                                    error.message

                                        ? error.message

                                        : 'Could not delete lesson.'
                                );
                            }
                        );
                }
            );
    }


    /* ======================================================================
       Save course settings
       ====================================================================== */

    function saveSettings() {

        var title =
            document
                .getElementById(
                    'courseTitle'
                )
                .value
                .trim();


        if (!title) {

            errorToast(
                'Please enter a course title before saving.'
            );

            return;
        }


        var category =
            document.getElementById(
                'courseCategory'
            );


        var difficulty =
            document.getElementById(
                'courseDifficulty'
            );


        var description =
            document
                .getElementById(
                    'courseDescription'
                )
                .value
                .trim();


        var categoryId =
            Number(
                category &&
                category.value
            ) ||
            null;


        if (!categoryId) {

            errorToast(
                'Please choose a category before saving.'
            );

            return;
        }


        LearnovaInstructorApi
            .updateCourse(
                courseId,
                {
                    categoryId:
                        categoryId,

                    title:
                        title,

                    shortDescription:
                        state.shortDescription ||
                        description,

                    description:
                        description,

                    difficulty:
                        (
                            difficulty &&
                            difficulty.value
                        ) ||
                        'beginner',

                    thumbnailUrl:
                        state.thumbnailUrl
                }
            )

            .then(
                function (course) {

                    state.shortDescription =
                        course &&
                        course.shortDescription

                            ? course.shortDescription

                            : state.shortDescription;


                    toast(
                        'Course settings saved.'
                    );
                }
            )

            .catch(
                function (error) {

                    errorToast(
                        error &&
                        error.message

                            ? error.message

                            : 'Could not save course settings.'
                    );
                }
            );
    }


    /* ======================================================================
       Events
       ====================================================================== */

    document.addEventListener(
        'DOMContentLoaded',
        function () {

            initializeAuthoringLinks();


            /*
             * Category and settings are independent calls.
             * Curriculum is also independent.
             *
             * Failure of one no longer prevents the others from loading.
             */
            loadCategories()
                .then(
                    loadSettings
                );


            loadCurriculum();


            var addModuleButton =
                document.getElementById(
                    'addModuleBtn'
                );


            if (addModuleButton) {

                addModuleButton.addEventListener(
                    'click',
                    addModule
                );
            }


            var curriculum =
                document.getElementById(
                    'curriculum'
                );


            if (curriculum) {

                curriculum.addEventListener(
                    'click',
                    function (event) {

                        var button =
                            event.target.closest(
                                '[data-action]'
                            );


                        if (!button) {
                            return;
                        }


                        var action =
                            button.dataset.action;


                        var moduleIndex =
                            Number(
                                button.dataset.m
                            );


                        if (
                            action ===
                            'add-lesson'
                        ) {

                            addLesson(
                                moduleIndex
                            );

                            return;
                        }


                        if (
                            action ===
                            'delete-module'
                        ) {

                            deleteModule(
                                moduleIndex
                            );

                            return;
                        }


                        if (
                            action ===
                            'delete-lesson'
                        ) {

                            deleteLesson(
                                moduleIndex,
                                Number(
                                    button.dataset.l
                                )
                            );
                        }
                    }
                );
            }


            var saveSettingsButton =
                document.getElementById(
                    'saveSettingsBtn'
                );


            if (saveSettingsButton) {

                saveSettingsButton.addEventListener(
                    'click',
                    saveSettings
                );
            }
        }
    );

})();