/* ==========================================================================
   Public Course Catalogue
   Search, filtering, sorting and pagination are performed by PostgreSQL.
   ========================================================================== */

(function () {
    'use strict';

    var target =
        document.getElementById('app-content') ||
        document.getElementById('catalogGrid');

    if (!target) {
        return;
    }

    if (
        !window.LearnovaCourseApi ||
        !window.LearnovaCourseCard
    ) {
        target.innerHTML =
            '<div class="catalog-state catalog-error">' +
                '<i class="fa-solid fa-triangle-exclamation"></i>' +
                '<h2>Catalogue could not start</h2>' +
                '<p>Required catalogue scripts were not loaded.</p>' +
            '</div>';

        return;
    }

    var state = {
        search: '',
        categoryId: '',
        difficulty: '',
        sort: 'relevance',
        page: 0,
        size: 12
    };

    var urlParams = new URLSearchParams(window.location.search);
    var urlSearch = (urlParams.get('search') || '').trim();
    if (urlSearch) {
        state.search = urlSearch;
    }

    var elements = {};
    var searchTimer = null;
    var latestRequestId = 0;

    function escapeHtml(value) {
        return String(
            value === null || value === undefined
                ? ''
                : value
        )
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function renderShell() {
        target.innerHTML =
            '<section class="catalog-shell">' +
                '<div class="catalog-heading">' +
                    '<div>' +
                        '<p class="catalog-kicker">Explore Learnova</p>' +
                        '<h1 class="page-title">Course Catalogue</h1>' +
                        '<p class="subtitle">' +
                            'Search published courses and discover your next skill.' +
                        '</p>' +
                    '</div>' +
                '</div>' +

                '<form class="catalog-toolbar" id="catalogForm">' +
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
                                '<option value="">All categories</option>' +
                            '</select>' +
                        '</label>' +

                        '<label class="catalog-field">' +
                            '<span>Difficulty</span>' +
                            '<select id="catalogDifficulty">' +
                                '<option value="">All levels</option>' +
                                '<option value="beginner">Beginner</option>' +
                                '<option value="intermediate">Intermediate</option>' +
                                '<option value="advanced">Advanced</option>' +
                            '</select>' +
                        '</label>' +

                        '<label class="catalog-field">' +
                            '<span>Sort by</span>' +
                            '<select id="catalogSort">' +
                                '<option value="relevance">Relevance</option>' +
                                '<option value="rating">Highest rating</option>' +
                                '<option value="newest">Newest</option>' +
                                '<option value="popular">Most popular</option>' +
                                '<option value="title">Title</option>' +
                            '</select>' +
                        '</label>' +
                    '</div>' +
                '</form>' +

                '<div class="catalog-notice" id="catalogNotice" hidden></div>' +

                '<div class="catalog-status-row">' +
                    '<p id="catalogStatus" class="catalog-status" aria-live="polite">' +
                        'Loading courses...' +
                    '</p>' +
                    '<button type="button" id="catalogClear" class="catalog-clear" hidden>' +
                        '<i class="fa-solid fa-rotate-left"></i> Clear filters' +
                    '</button>' +
                '</div>' +

                '<div class="course-grid" id="catalogGrid" aria-live="polite"></div>' +

                '<nav class="catalog-pagination" id="catalogPagination" ' +
                    'aria-label="Course catalogue pagination"></nav>' +
            '</section>';

        elements.form =
            document.getElementById('catalogForm');

        elements.search =
            document.getElementById('catalogSearch');

        elements.category =
            document.getElementById('catalogCategory');

        elements.difficulty =
            document.getElementById('catalogDifficulty');

        elements.sort =
            document.getElementById('catalogSort');

        elements.notice =
            document.getElementById('catalogNotice');

        elements.status =
            document.getElementById('catalogStatus');

        elements.clear =
            document.getElementById('catalogClear');

        elements.grid =
            document.getElementById('catalogGrid');

        elements.pagination =
            document.getElementById('catalogPagination');
    }

    function hasActiveFilters() {
        return Boolean(
            state.search ||
            state.categoryId ||
            state.difficulty ||
            state.sort !== 'relevance'
        );
    }

    function updateClearButton() {
        elements.clear.hidden = !hasActiveFilters();
    }

    function showNotice(message, type) {
        elements.notice.className =
            'catalog-notice catalog-notice-' +
            (type || 'info');

        elements.notice.textContent = message;
        elements.notice.hidden = false;
    }

    function hideNotice() {
        elements.notice.hidden = true;
        elements.notice.textContent = '';
    }

    function setLoading() {
        elements.status.textContent =
            'Loading courses...';

        elements.grid.innerHTML =
            '<div class="catalog-state catalog-loading">' +
                '<span class="catalog-spinner" aria-hidden="true"></span>' +
                '<h2>Loading catalogue</h2>' +
                '<p>Please wait while published courses are loaded.</p>' +
            '</div>';

        elements.pagination.innerHTML = '';
    }

    function renderEmpty() {
        elements.grid.innerHTML =
            '<div class="catalog-state catalog-empty">' +
                '<i class="fa-solid fa-book-open"></i>' +
                '<h2>No courses found</h2>' +
                '<p>Try changing your search or filters.</p>' +
            '</div>';
    }

    function renderError(error) {
        var message =
            error && error.message
                ? error.message
                : 'The catalogue request failed.';

        elements.status.textContent =
            'Could not load courses.';

        elements.grid.innerHTML =
            '<div class="catalog-state catalog-error">' +
                '<i class="fa-solid fa-triangle-exclamation"></i>' +
                '<h2>Unable to load courses</h2>' +
                '<p>' + escapeHtml(message) + '</p>' +
                '<button type="button" class="catalog-retry" id="catalogRetry">' +
                    '<i class="fa-solid fa-rotate-right"></i> Try again' +
                '</button>' +
            '</div>';

        elements.pagination.innerHTML = '';

        var retryButton =
            document.getElementById('catalogRetry');

        if (retryButton) {
            retryButton.addEventListener(
                'click',
                loadCourses
            );
        }
    }

    function renderCourses(pageData) {
        var courses = Array.isArray(pageData.content)
            ? pageData.content
            : [];

        if (courses.length === 0) {
            renderEmpty();
            return;
        }

        elements.grid.innerHTML = courses
            .map(function (course) {
                return LearnovaCourseCard.render(course);
            })
            .join('');
    }

    function renderStatus(pageData) {
        var total = Number(pageData.totalElements) || 0;
        var page = Number(pageData.page) || 0;
        var size = Number(pageData.size) || state.size;

        if (total === 0) {
            elements.status.textContent =
                'No published courses match your selection.';

            return;
        }

        var firstItem = page * size + 1;
        var lastItem = Math.min(
            firstItem + size - 1,
            total
        );

        elements.status.textContent =
            'Showing ' +
            firstItem +
            '–' +
            lastItem +
            ' of ' +
            total +
            (total === 1 ? ' course' : ' courses');
    }

    function paginationButton(label, page, disabled, iconClass) {
        return (
            '<button ' +
                'type="button" ' +
                'class="pagination-btn" ' +
                'data-page="' + page + '" ' +
                (disabled ? 'disabled ' : '') +
            '>' +
                (
                    iconClass
                        ? '<i class="' + iconClass + '"></i> '
                        : ''
                ) +
                escapeHtml(label) +
            '</button>'
        );
    }

    function renderPagination(pageData) {
        var page = Number(pageData.page) || 0;
        var totalPages =
            Number(pageData.totalPages) || 0;

        if (totalPages <= 1) {
            elements.pagination.innerHTML = '';
            return;
        }

        elements.pagination.innerHTML =
            paginationButton(
                'Previous',
                page - 1,
                Boolean(pageData.first),
                'fa-solid fa-chevron-left'
            ) +
            '<span class="pagination-summary">' +
                'Page ' +
                (page + 1) +
                ' of ' +
                totalPages +
            '</span>' +
            paginationButton(
                'Next',
                page + 1,
                Boolean(pageData.last),
                ''
            ).replace(
                '</button>',
                ' <i class="fa-solid fa-chevron-right"></i></button>'
            );

        Array.prototype.forEach.call(
            elements.pagination.querySelectorAll(
                '[data-page]'
            ),
            function (button) {
                button.addEventListener(
                    'click',
                    function () {
                        if (button.disabled) {
                            return;
                        }

                        state.page = Number(
                            button.getAttribute('data-page')
                        );

                        loadCourses();

                        window.scrollTo({
                            top: 0,
                            behavior: 'smooth'
                        });
                    }
                );
            }
        );
    }

    function loadCategories() {
        return LearnovaCourseApi
            .getCatalogueCategories()
            .then(function (categories) {
                var list = Array.isArray(categories)
                    ? categories
                    : [];

                elements.category.innerHTML =
                    '<option value="">All categories</option>' +
                    list.map(function (category) {
                        return (
                            '<option value="' +
                            escapeHtml(category.id) +
                            '">' +
                            escapeHtml(category.name) +
                            '</option>'
                        );
                    }).join('');

                if (state.categoryId) {
                    elements.category.value =
                        String(state.categoryId);
                }
            })
            .catch(function (error) {
                showNotice(
                    'Categories could not be loaded. ' +
                    'Courses are still available.',
                    'warning'
                );

                console.error(
                    'Category loading failed:',
                    error
                );
            });
    }

    function loadCourses() {
        var requestId = ++latestRequestId;

        setLoading();
        updateClearButton();

        LearnovaCourseApi
            .searchCourses({
                search: state.search,
                categoryId: state.categoryId,
                difficulty: state.difficulty,
                sort: state.sort,
                page: state.page,
                size: state.size
            })
            .then(function (pageData) {
                if (requestId !== latestRequestId) {
                    return;
                }

                hideNotice();
                renderStatus(pageData);
                renderCourses(pageData);
                renderPagination(pageData);
            })
            .catch(function (error) {
                if (requestId !== latestRequestId) {
                    return;
                }

                renderError(error);
            });
    }

    function clearFilters() {
        state.search = '';
        state.categoryId = '';
        state.difficulty = '';
        state.sort = 'relevance';
        state.page = 0;

        elements.search.value = '';
        elements.category.value = '';
        elements.difficulty.value = '';
        elements.sort.value = 'relevance';

        loadCourses();
    }

    function bindEvents() {
        elements.form.addEventListener(
            'submit',
            function (event) {
                event.preventDefault();

                clearTimeout(searchTimer);

                state.search =
                    elements.search.value.trim();

                state.page = 0;
                loadCourses();
            }
        );

        elements.search.addEventListener(
            'input',
            function () {
                clearTimeout(searchTimer);

                searchTimer = setTimeout(
                    function () {
                        state.search =
                            elements.search.value.trim();

                        state.page = 0;
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

                state.page = 0;
                loadCourses();
            }
        );

        elements.difficulty.addEventListener(
            'change',
            function () {
                state.difficulty =
                    elements.difficulty.value;

                state.page = 0;
                loadCourses();
            }
        );

        elements.sort.addEventListener(
            'change',
            function () {
                state.sort =
                    elements.sort.value;

                state.page = 0;
                loadCourses();
            }
        );

        elements.clear.addEventListener(
            'click',
            clearFilters
        );
    }

    renderShell();
    bindEvents();

    if (state.search) {
        elements.search.value = state.search;
    }

    loadCategories();
    loadCourses();
})();
