/* ==========================================================================
   Student Course Catalog
   Renders a course catalog grid into #app-content (or #catalogGrid) using
   the Academos .course-card structure (image block, tag pill, rating,
   title, author) with a client-side search filter by title.
   ========================================================================== */
(function () {
    'use strict';

    var appContent = document.getElementById('app-content');
    var catalogGrid = document.getElementById('catalogGrid');
    var target = appContent || catalogGrid;
    if (!target) return;

    /* ---------- Mock Course Data ---------- */
    var courses = [
        {
            title: 'SQL Fundamentals',
            author: 'By Prof. Alan Turing',
            category: 'Beginner',
            rating: '4.8',
            courseKey: 'datascience'
        },
        {
            title: 'Introduction to Databases',
            author: 'By Dr. Grace Hopper',
            category: 'Beginner',
            rating: '4.7',
            courseKey: 'frontend'
        },
        {
            title: 'Advanced SQL & Optimization',
            author: 'By Dr. Edgar Codd',
            category: 'Advanced',
            rating: '4.9',
            courseKey: 'backend'
        },
        {
            title: 'Data Warehousing & ETL',
            author: 'By Priya Sharma',
            category: 'Intermediate',
            rating: '4.6',
            courseKey: 'datascience'
        },
        {
            title: 'Machine Learning Foundations',
            author: 'By Dr. Andrew Lee',
            category: 'Intermediate',
            rating: '4.8',
            courseKey: 'machinelearning'
        },
        {
            title: 'Modern Frontend Development',
            author: 'By Sarah Jenkins',
            category: 'Intermediate',
            rating: '4.5',
            courseKey: 'frontend'
        }
    ];

    /* ---------- Template Helpers ---------- */
    function courseCardHtml(course) {
        return '<article class="course-card">' +
            '<div class="card-image-block" data-course="' + course.courseKey + '"><span>[ Course Thumbnail ]</span></div>' +
            '<div class="card-content-block">' +
                '<div class="card-tags-row">' +
                    '<span class="tag-pill">' + course.category + '</span>' +
                    '<span class="rating-star">★ ' + course.rating + '</span>' +
                '</div>' +
                '<h3 class="card-title">' + course.title + '</h3>' +
                '<p class="card-author">' + course.author + '</p>' +
            '</div>' +
        '</article>';
    }

    function noResultsHtml() {
        return '<p class="text-muted">No courses match your search.</p>';
    }

    /* ---------- Render ---------- */
    var grid;

    function renderGrid(filter) {
        var term = (filter || '').trim().toLowerCase();
        var matches = courses.filter(function (course) {
            return !term || course.title.toLowerCase().indexOf(term) !== -1;
        });

        if (matches.length === 0) {
            grid.innerHTML = noResultsHtml();
            return;
        }

        grid.innerHTML = matches.map(courseCardHtml).join('');
    }

    function renderCatalog() {
        target.innerHTML =
            '<h1 class="page-title">Course Catalog</h1>' +
            '<p class="subtitle">Discover new skills and add them to your learning tracks.</p>' +

            '<div class="catalog-toolbar">' +
                '<div class="catalog-search">' +
                    '<i class="fa-solid fa-magnifying-glass"></i>' +
                    '<input type="text" id="catalogSearch" placeholder="Search by title...">' +
                '</div>' +
            '</div>' +

            '<div class="course-grid" id="catalogGrid"></div>';

        grid = document.getElementById('catalogGrid');
        if (!grid) return;

        renderGrid('');

        var searchInput = document.getElementById('catalogSearch');
        if (searchInput) {
            searchInput.addEventListener('input', function () {
                renderGrid(searchInput.value);
            });
        }
    }

    renderCatalog();
})();
