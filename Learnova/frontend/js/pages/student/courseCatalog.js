/* ==========================================================================
   Student Course Catalog
   Renders the published course catalogue into #app-content (catalog.html).
   Fully data-driven: categories, search, difficulty/category filters and
   sorting come from the backend (fn_search_course_catalogue); the page never
   hardcodes courses or business rules. Cards are built by LearnovaCourseCard.
   ========================================================================== */
(function () {
    'use strict';

    var appContent = document.getElementById('app-content');
    var target = appContent || document.getElementById('catalogGrid');
    if (!target) return;

    var CONSTANTS = window.LearnovaConstants || {};
    var STATUS = CONSTANTS.COURSE_STATUS || {};
    var SORTS = CONSTANTS.COURSE_SORT_OPTIONS || {
        RELEVANCE: 'relevance',
        RATING: 'rating',
        NEWEST: 'newest',
        TITLE: 'title'
    };
    var DIFFICULTIES = CONSTANTS.COURSE_DIFFICULTIES || [
        'beginner',
        'intermediate',
        'advanced'
    ];

    var PAGE_SIZE = CONSTANTS.CATALOGUE_PAGE_SIZE || 12;

    var state = {
        search: '',
        categoryId: null,
        difficulty: '',
        sort: SORTS.RELEVANCE,
        page: 0,
        totalPages: 0,
        totalElements: 0,
        categories: [],
        categoriesLoaded: false
    };

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    /* Backend returns {content, page, size, totalElements, totalPages, first,
       last}; the offline mock returns a plain array. Normalize both. */
    function normalizePage(result) {
        if (result && Array.isArray(result.content)) {
            return result;
        }
        if (Array.isArray(result)) {
            return {
                content: result,
                page: 0,
                size: result.length,
                totalElements: result.length,
                totalPages: 1,
                first: true,
                last: true
            };
        }
        return {
            content: [],
            page: 0,
            size: PAGE_SIZE,
            totalElements: 0,
            totalPages: 0,
            first: true,
            last: true
        };
    }

    /* The catalogue only ever shows published courses. The backend already
       enforces this; the mock fallback carries draft/pending rows too, so
       filter them here when the rows expose a lifecycle status. */
    function publishedOnly(content) {
        return content.filter(function (course) {
            if (!course || !course.status) return true;
            return String(course.status).toLowerCase() === STATUS.PUBLISHED;
        });
    }

    /* ---------- Data ---------- */

    function loadCategories() {
        return LearnovaCourseApi.getCatalogueCategories()
            .then(function (categories) {
                state.categories = Array.isArray(categories) ? categories : [];
                state.categoriesLoaded = true;
                populateCategorySelect();
                return state.categories;
            })
            .catch(function () {
                state.categories = [];
                state.categoriesLoaded = true;
                populateCategorySelect();
                return [];
            });
    }

    function loadCourses() {
        return LearnovaCourseApi.searchCourses({
            search: state.search,
            categoryId: state.categoryId,
            difficulty: state.difficulty,
            sort: state.sort,
            page: state.page,
            size: PAGE_SIZE
        }).then(normalizePage).then(function (page) {
            state.page = page.page || 0;
            state.totalPages = page.totalPages || 0;
            state.totalElements = page.totalElements || 0;
            renderGrid(page.content);
            renderPager();
        }).catch(function (err) {
            renderGrid([]);
            renderError((err && err.message) || 'Could not load the catalogue.');
        });
    }

    /* ---------- Rendering ---------- */

    function renderError(message) {
        var grid = document.getElementById('catalogGrid');
        if (!grid) return;
        grid.innerHTML =
            '<div class="empty-state">' +
                '<div class="empty-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>' +
                '<h3>Could not load the catalogue</h3>' +
                '<p>' + esc(message) + '</p>' +
            '</div>';
    }

    function renderGrid(content) {
        var grid = document.getElementById('catalogGrid');
        if (!grid) return;

        var courses = publishedOnly(content || []);

        if (!courses.length) {
            grid.innerHTML =
                '<div class="empty-state">' +
                    '<div class="empty-icon"><i class="fa-solid fa-sparkles"></i></div>' +
                    '<h3>No published courses found</h3>' +
                    '<p>' +
                        (
                            state.search || state.categoryId || state.difficulty
                                ? 'Try adjusting your search or filters.'
                                : 'Instructors create courses and admins publish them. Check back soon.'
                        ) +
                    '</p>' +
                '</div>';
            return;
        }

        grid.innerHTML = courses.map(function (course) {
            return LearnovaCourseCard.render(course);
        }).join('');
    }

    function renderPager() {
        var box = document.getElementById('catalogPager');
        if (!box) return;

        if (state.totalPages <= 1) {
            box.innerHTML = '';
            return;
        }

        var current = state.page + 1;
        box.innerHTML =
            '<span class="catalog-pager-info">Page ' + current + ' of ' + state.totalPages + '</span>' +
            '<div class="catalog-pager-buttons">' +
                '<button class="btn btn-outline btn-sm" id="catalogPrevBtn"' +
                    (state.page <= 0 ? ' disabled' : '') + '>&laquo; Previous</button>' +
                '<button class="btn btn-outline btn-sm" id="catalogNextBtn"' +
                    (state.page >= state.totalPages - 1 ? ' disabled' : '') + '>Next &raquo;</button>' +
            '</div>';

        var prevBtn = document.getElementById('catalogPrevBtn');
        var nextBtn = document.getElementById('catalogNextBtn');
        if (prevBtn) prevBtn.addEventListener('click', function () {
            if (state.page > 0) { state.page -= 1; loadCourses(); }
        });
        if (nextBtn) nextBtn.addEventListener('click', function () {
            if (state.page < state.totalPages - 1) { state.page += 1; loadCourses(); }
        });
    }

    function populateCategorySelect() {
        var select = document.getElementById('catalogCategory');
        if (!select) return;

        var options = '<option value="">All categories</option>';
        options += state.categories.map(function (category) {
            return '<option value="' + esc(category.id) + '">' +
                esc(category.name) + '</option>';
        }).join('');

        select.innerHTML = options;
    }

    /* ---------- Toolbar + shell ---------- */

    function renderShell() {
        var sortOptions = [
            { value: SORTS.RELEVANCE, label: 'Relevance' },
            { value: SORTS.RATING, label: 'Top Rated' },
            { value: SORTS.NEWEST, label: 'Newest' },
            { value: SORTS.TITLE, label: 'Title A-Z' }
        ];

        target.innerHTML =
            '<h1 class="page-title">Course Catalog</h1>' +
            '<p class="subtitle">Discover new skills and add them to your learning tracks.</p>' +

            '<div class="catalog-toolbar">' +
                '<div class="catalog-search">' +
                    '<i class="fa-solid fa-magnifying-glass"></i>' +
                    '<input type="text" id="catalogSearch" placeholder="Search by title or description...">' +
                '</div>' +
            '</div>' +

            '<div class="catalog-filters">' +
                '<select id="catalogCategory" aria-label="Category">' +
                    '<option value="">All categories</option>' +
                '</select>' +
                '<select id="catalogDifficulty" aria-label="Difficulty">' +
                    '<option value="">All difficulties</option>' +
                    DIFFICULTIES.map(function (level) {
                        return '<option value="' + esc(level) + '">' +
                            esc(level.charAt(0).toUpperCase() + level.slice(1)) + '</option>';
                    }).join('') +
                '</select>' +
                '<select id="catalogSort" aria-label="Sort">' +
                    sortOptions.map(function (option) {
                        return '<option value="' + esc(option.value) + '">' +
                            esc(option.label) + '</option>';
                    }).join('') +
                '</select>' +
            '</div>' +

            '<div class="course-grid" id="catalogGrid"></div>' +
            '<div class="catalog-pager" id="catalogPager"></div>';
    }

    function wireControls() {
        var searchInput = document.getElementById('catalogSearch');
        if (searchInput) {
            var debounceTimer = null;
            searchInput.addEventListener('input', function () {
                if (debounceTimer) window.clearTimeout(debounceTimer);
                debounceTimer = window.setTimeout(function () {
                    state.search = searchInput.value.trim();
                    state.page = 0;
                    loadCourses();
                }, 300);
            });
        }

        var categorySelect = document.getElementById('catalogCategory');
        if (categorySelect) categorySelect.addEventListener('change', function () {
            var value = categorySelect.value;
            state.categoryId = value === '' ? null : Number(value);
            state.page = 0;
            loadCourses();
        });

        var difficultySelect = document.getElementById('catalogDifficulty');
        if (difficultySelect) difficultySelect.addEventListener('change', function () {
            state.difficulty = difficultySelect.value;
            state.page = 0;
            loadCourses();
        });

        var sortSelect = document.getElementById('catalogSort');
        if (sortSelect) sortSelect.addEventListener('change', function () {
            state.sort = sortSelect.value;
            state.page = 0;
            loadCourses();
        });

        document.addEventListener('click', function (event) {
            var card = event.target.closest('.course-card[data-course-id]');
            if (!card) return;
            var courseId = card.getAttribute('data-course-id');
            if (!courseId) return;
            window.location.href =
                'course-detail.html?course=' + encodeURIComponent(courseId);
        });
    }

    /* ---------- Init ---------- */

    renderShell();
    wireControls();
    loadCategories().then(function () {
        loadCourses();
    }).catch(function () {
        loadCourses();
    });
})();
