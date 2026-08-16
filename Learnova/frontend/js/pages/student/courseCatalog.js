/* ==========================================================================
   Learnova Student Course Catalog
   --------------------------------------------------------------------------
   Canonical API:

       GET /api/v1/categories
       GET /api/v1/courses

   PostgreSQL/Spring owns:
       - published-course filtering
       - search
       - category filtering
       - difficulty filtering
       - sorting
       - pagination
       - personalized access state

   Frontend owns only presentation and interaction.
   ========================================================================== */

(function () {
    'use strict';


    /* ======================================================================
       Bootstrap
       ====================================================================== */

    var root =
        document.getElementById(
            'app-content'
        );

    if (!root) {
        return;
    }


    if (
        !window.LearnovaCourseApi ||
        !window.LearnovaCourseCard
    ) {

        root.innerHTML =
            '<div class="catalog-state catalog-error">' +
                '<i class="fa-solid fa-triangle-exclamation"></i>' +
                '<h2>Catalog could not start</h2>' +
                '<p>Required catalog components were not loaded.</p>' +
            '</div>';

        return;
    }


    /* ======================================================================
       State
       ====================================================================== */

    var state = {
        search: '',
        categoryId: '',
        difficulty: '',
        sort: 'relevance',
        page: 0,
        size: 12,

        categoryWarning: null
    };


    var elements = {};

    var searchTimer = null;

    var latestRequestId = 0;


    /* ======================================================================
       URL initialization
       ====================================================================== */

    function initializeFromUrl() {
        var params =
            new URLSearchParams(
                window.location.search
            );


        state.search =
            String(
                params.get('search') || ''
            ).trim();


        state.categoryId =
            String(
                params.get('categoryId') || ''
            ).trim();


        state.difficulty =
            String(
                params.get('difficulty') || ''
            )
                .trim()
                .toLowerCase();


        var requestedSort =
            String(
                params.get('sort') || ''
            )
                .trim()
                .toLowerCase();


        if (
            [
                'relevance',
                'rating',
                'newest',
                'popular',
                'title'
            ].indexOf(requestedSort) !== -1
        ) {
            state.sort =
                requestedSort;
        }


        var requestedPage =
            Number(
                params.get('page')
            );


        if (
            Number.isInteger(requestedPage) &&
            requestedPage >= 0
        ) {
            state.page =
                requestedPage;
        }
    }


    /* ======================================================================
       Helpers
       ====================================================================== */

    function escapeHtml(value) {
        return String(
            value === null ||
            value === undefined
                ? ''
                : value
        )
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }


    function hasActiveFilters() {
        return Boolean(
            state.search ||
            state.categoryId ||
            state.difficulty ||
            state.sort !== 'relevance'
        );
    }


    function syncUrl() {
        var params =
            new URLSearchParams();


        if (state.search) {
            params.set(
                'search',
                state.search
            );
        }


        if (state.categoryId) {
            params.set(
                'categoryId',
                state.categoryId
            );
        }


        if (state.difficulty) {
            params.set(
                'difficulty',
                state.difficulty
            );
        }


        if (state.sort !== 'relevance') {
            params.set(
                'sort',
                state.sort
            );
        }


        if (state.page > 0) {
            params.set(
                'page',
                String(state.page)
            );
        }


        var query =
            params.toString();


        var nextUrl =
            window.location.pathname +
            (
                query
                    ? '?' + query
                    : ''
            );


        window.history.replaceState(
            null,
            '',
            nextUrl
        );
    }


    /* ======================================================================
       Shell
       ====================================================================== */

    function renderShell() {
        root.innerHTML =

            '<section class="catalog-shell">' +

                '<div class="catalog-heading">' +

                    '<div>' +

                        '<p class="catalog-kicker">' +
                            'Explore Learnova' +
                        '</p>' +

                        '<h1 class="page-title">' +
                            'Course Catalog' +
                        '</h1>' +

                        '<p class="subtitle">' +
                            'Search published courses and discover your next skill.' +
                        '</p>' +

                    '</div>' +

                '</div>' +


                '<form ' +
                    'class="catalog-toolbar" ' +
                    'id="catalogForm">' +


                    '<div class="catalog-search">' +

                        '<i class="fa-solid fa-magnifying-glass"></i>' +

                        '<input ' +
                            'type="search" ' +
                            'id="catalogSearch" ' +
                            'placeholder="Search courses..." ' +
                            'autocomplete="off" ' +
                            'aria-label="Search courses">' +

                    '</div>' +


                    '<div class="catalog-filters">' +


                        '<label class="catalog-field">' +

                            '<span>Category</span>' +

                            '<select id="catalogCategory">' +
                                '<option value="">' +
                                    'All categories' +
                                '</option>' +
                            '</select>' +

                        '</label>' +


                        '<label class="catalog-field">' +

                            '<span>Difficulty</span>' +

                            '<select id="catalogDifficulty">' +

                                '<option value="">' +
                                    'All levels' +
                                '</option>' +

                                '<option value="beginner">' +
                                    'Beginner' +
                                '</option>' +

                                '<option value="intermediate">' +
                                    'Intermediate' +
                                '</option>' +

                                '<option value="advanced">' +
                                    'Advanced' +
                                '</option>' +

                            '</select>' +

                        '</label>' +


                        '<label class="catalog-field">' +

                            '<span>Sort by</span>' +

                            '<select id="catalogSort">' +

                                '<option value="relevance">' +
                                    'Relevance' +
                                '</option>' +

                                '<option value="rating">' +
                                    'Highest rating' +
                                '</option>' +

                                '<option value="newest">' +
                                    'Newest' +
                                '</option>' +

                                '<option value="popular">' +
                                    'Most popular' +
                                '</option>' +

                                '<option value="title">' +
                                    'Title' +
                                '</option>' +

                            '</select>' +

                        '</label>' +


                    '</div>' +

                '</form>' +


                '<div ' +
                    'class="catalog-notice" ' +
                    'id="catalogNotice" ' +
                    'hidden>' +
                '</div>' +


                '<div class="catalog-status-row">' +

                    '<p ' +
                        'id="catalogStatus" ' +
                        'class="catalog-status" ' +
                        'aria-live="polite">' +
                        'Loading courses...' +
                    '</p>' +

                    '<button ' +
                        'type="button" ' +
                        'id="catalogClear" ' +
                        'class="catalog-clear" ' +
                        'hidden>' +

                        '<i class="fa-solid fa-rotate-left"></i> ' +
                        'Clear filters' +

                    '</button>' +

                '</div>' +


                '<div ' +
                    'class="course-grid" ' +
                    'id="catalogGrid" ' +
                    'aria-live="polite">' +
                '</div>' +


                '<nav ' +
                    'class="catalog-pagination" ' +
                    'id="catalogPagination" ' +
                    'aria-label="Course catalog pagination">' +
                '</nav>' +


            '</section>';


        elements.form =
            document.getElementById(
                'catalogForm'
            );

        elements.search =
            document.getElementById(
                'catalogSearch'
            );

        elements.category =
            document.getElementById(
                'catalogCategory'
            );

        elements.difficulty =
            document.getElementById(
                'catalogDifficulty'
            );

        elements.sort =
            document.getElementById(
                'catalogSort'
            );

        elements.notice =
            document.getElementById(
                'catalogNotice'
            );

        elements.status =
            document.getElementById(
                'catalogStatus'
            );

        elements.clear =
            document.getElementById(
                'catalogClear'
            );

        elements.grid =
            document.getElementById(
                'catalogGrid'
            );

        elements.pagination =
            document.getElementById(
                'catalogPagination'
            );


        elements.search.value =
            state.search;

        elements.difficulty.value =
            state.difficulty;

        elements.sort.value =
            state.sort;
    }


    /* ======================================================================
       Notice
       ====================================================================== */

    function renderNotice() {
        if (!state.categoryWarning) {

            elements.notice.hidden =
                true;

            elements.notice.textContent =
                '';

            return;
        }


        elements.notice.className =
            'catalog-notice catalog-notice-warning';


        elements.notice.textContent =
            state.categoryWarning;


        elements.notice.hidden =
            false;
    }


    /* ======================================================================
       Loading / error / empty
       ====================================================================== */

    function updateClearButton() {
        elements.clear.hidden =
            !hasActiveFilters();
    }


    function renderLoading() {
        elements.status.textContent =
            'Loading courses...';


        elements.grid.innerHTML =

            '<div class="catalog-state catalog-loading">' +

                '<span ' +
                    'class="catalog-spinner" ' +
                    'aria-hidden="true">' +
                '</span>' +

                '<h2>Loading catalog</h2>' +

                '<p>' +
                    'Please wait while published courses are loaded.' +
                '</p>' +

            '</div>';


        elements.pagination.innerHTML =
            '';
    }


    function renderEmpty() {
        elements.grid.innerHTML =

            '<div class="catalog-state catalog-empty">' +

                '<i class="fa-solid fa-book-open"></i>' +

                '<h2>No courses found</h2>' +

                '<p>' +
                    'Try changing your search or filters.' +
                '</p>' +

            '</div>';
    }


    function renderError(error) {
        var message =
            error &&
            error.message

                ? error.message

                : 'The catalog request failed.';


        elements.status.textContent =
            'Could not load courses.';


        elements.grid.innerHTML =

            '<div class="catalog-state catalog-error">' +

                '<i class="fa-solid fa-triangle-exclamation"></i>' +

                '<h2>Unable to load courses</h2>' +

                '<p>' +
                    escapeHtml(message) +
                '</p>' +

                '<button ' +
                    'type="button" ' +
                    'class="catalog-retry" ' +
                    'id="catalogRetry">' +

                    '<i class="fa-solid fa-rotate-right"></i> ' +
                    'Try again' +

                '</button>' +

            '</div>';


        elements.pagination.innerHTML =
            '';


        var retry =
            document.getElementById(
                'catalogRetry'
            );


        if (retry) {

            retry.addEventListener(
                'click',
                loadCourses
            );
        }
    }


    /* ======================================================================
       Categories
       ====================================================================== */

    function loadCategories() {
        return LearnovaCourseApi
            .getCategories()

            .then(function (categories) {

                var list =
                    Array.isArray(categories)
                        ? categories
                        : [];


                while (
                    elements.category.options.length > 1
                ) {
                    elements.category.remove(1);
                }


                list.forEach(
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


                        elements.category.appendChild(
                            option
                        );
                    }
                );


                if (state.categoryId) {
                    elements.category.value =
                        state.categoryId;
                }


                state.categoryWarning =
                    null;


                renderNotice();
            })

            .catch(function (error) {

                state.categoryWarning =
                    'Categories could not be loaded. ' +
                    'Course search is still available.';


                renderNotice();


                console.error(
                    'Category loading failed:',
                    error
                );
            });
    }


    /* ======================================================================
       Course rendering
       ====================================================================== */

    function renderCourses(pageData) {
        var courses =
            Array.isArray(
                pageData.content
            )
                ? pageData.content
                : [];


        if (!courses.length) {
            renderEmpty();
            return;
        }


        elements.grid.innerHTML =
            courses
                .map(
                    function (course) {
                        return LearnovaCourseCard
                            .render(course);
                    }
                )
                .join('');
    }


    function renderStatus(pageData) {
        var total =
            Number(
                pageData.totalElements
            ) || 0;


        var page =
            Number(
                pageData.page
            ) || 0;


        var size =
            Number(
                pageData.size
            ) || state.size;


        if (!total) {

            elements.status.textContent =
                'No published courses match your selection.';

            return;
        }


        var first =
            page * size + 1;


        var last =
            Math.min(
                first + size - 1,
                total
            );


        elements.status.textContent =
            'Showing ' +
            first +
            '–' +
            last +
            ' of ' +
            total +
            (
                total === 1
                    ? ' course'
                    : ' courses'
            );
    }


    /* ======================================================================
       Pagination
       ====================================================================== */

    function createPageButton(
        label,
        targetPage,
        disabled,
        icon,
        iconAfter
    ) {
        var button =
            document.createElement(
                'button'
            );


        button.type =
            'button';


        button.className =
            'pagination-btn';


        button.dataset.page =
            String(targetPage);


        button.disabled =
            Boolean(disabled);


        if (
            icon &&
            !iconAfter
        ) {

            var before =
                document.createElement(
                    'i'
                );

            before.className =
                icon;

            button.appendChild(
                before
            );

            button.appendChild(
                document.createTextNode(' ')
            );
        }


        button.appendChild(
            document.createTextNode(
                label
            )
        );


        if (
            icon &&
            iconAfter
        ) {

            button.appendChild(
                document.createTextNode(' ')
            );


            var after =
                document.createElement(
                    'i'
                );

            after.className =
                icon;

            button.appendChild(
                after
            );
        }


        return button;
    }


    function renderPagination(pageData) {
        elements.pagination.innerHTML =
            '';


        var currentPage =
            Number(
                pageData.page
            ) || 0;


        var totalPages =
            Number(
                pageData.totalPages
            ) || 0;


        if (totalPages <= 1) {
            return;
        }


        var previous =
            createPageButton(
                'Previous',
                currentPage - 1,
                Boolean(pageData.first),
                'fa-solid fa-chevron-left',
                false
            );


        var summary =
            document.createElement(
                'span'
            );


        summary.className =
            'pagination-summary';


        summary.textContent =
            'Page ' +
            (currentPage + 1) +
            ' of ' +
            totalPages;


        var next =
            createPageButton(
                'Next',
                currentPage + 1,
                Boolean(pageData.last),
                'fa-solid fa-chevron-right',
                true
            );


        elements.pagination.appendChild(
            previous
        );

        elements.pagination.appendChild(
            summary
        );

        elements.pagination.appendChild(
            next
        );
    }


    /* ======================================================================
       Course request
       ====================================================================== */

    function loadCourses() {
        var requestId =
            ++latestRequestId;


        renderLoading();

        updateClearButton();

        syncUrl();


        return LearnovaCourseApi
            .searchCourses({
                search: state.search,
                categoryId: state.categoryId,
                difficulty: state.difficulty,
                sort: state.sort,
                page: state.page,
                size: state.size
            })

            .then(function (pageData) {

                if (
                    requestId !==
                    latestRequestId
                ) {
                    return;
                }


                /*
                 * Backend may normalize an out-of-range page.
                 * Keep local state aligned with server response.
                 */
                state.page =
                    Number(
                        pageData.page
                    ) || 0;


                renderStatus(
                    pageData
                );


                renderCourses(
                    pageData
                );


                renderPagination(
                    pageData
                );


                updateClearButton();

                syncUrl();
            })

            .catch(function (error) {

                if (
                    requestId !==
                    latestRequestId
                ) {
                    return;
                }


                renderError(
                    error
                );
            });
    }


    /* ======================================================================
       Clear
       ====================================================================== */

    function clearFilters() {
        clearTimeout(
            searchTimer
        );


        state.search =
            '';

        state.categoryId =
            '';

        state.difficulty =
            '';

        state.sort =
            'relevance';

        state.page =
            0;


        elements.search.value =
            '';

        elements.category.value =
            '';

        elements.difficulty.value =
            '';

        elements.sort.value =
            'relevance';


        loadCourses();
    }


    /* ======================================================================
       Events
       ====================================================================== */

    function bindEvents() {
        elements.form.addEventListener(
            'submit',
            function (event) {

                event.preventDefault();

                clearTimeout(
                    searchTimer
                );


                state.search =
                    elements.search.value
                        .trim();


                state.page =
                    0;


                loadCourses();
            }
        );


        elements.search.addEventListener(
            'input',
            function () {

                clearTimeout(
                    searchTimer
                );


                searchTimer =
                    setTimeout(
                        function () {

                            state.search =
                                elements.search.value
                                    .trim();


                            state.page =
                                0;


                            loadCourses();
                        },
                        350
                    );
            }
        );


        elements.category.addEventListener(
            'change',
            function () {

                state.categoryId =
                    elements.category.value;


                state.page =
                    0;


                loadCourses();
            }
        );


        elements.difficulty.addEventListener(
            'change',
            function () {

                state.difficulty =
                    elements.difficulty.value;


                state.page =
                    0;


                loadCourses();
            }
        );


        elements.sort.addEventListener(
            'change',
            function () {

                state.sort =
                    elements.sort.value;


                state.page =
                    0;


                loadCourses();
            }
        );


        elements.clear.addEventListener(
            'click',
            clearFilters
        );


        elements.pagination.addEventListener(
            'click',
            function (event) {

                var button =
                    event.target.closest(
                        '[data-page]'
                    );


                if (
                    !button ||
                    button.disabled
                ) {
                    return;
                }


                var nextPage =
                    Number(
                        button.dataset.page
                    );


                if (
                    !Number.isInteger(nextPage) ||
                    nextPage < 0
                ) {
                    return;
                }


                state.page =
                    nextPage;


                loadCourses();


                window.scrollTo({
                    top: 0,
                    behavior: 'smooth'
                });
            }
        );
    }


    /* ======================================================================
       Start
       ====================================================================== */

    initializeFromUrl();

    renderShell();

    bindEvents();

    loadCategories();

    loadCourses();

})();