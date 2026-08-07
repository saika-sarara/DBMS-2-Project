/* ==========================================================================
   Learnova API Client (window.LearnovaApiClient)
   Thin fetch wrapper: JSON in/out, bearer auth from session, error throwing.
   ========================================================================== */

window.LearnovaApiClient = (function () {
    'use strict';

    var REQUEST_TIMEOUT_MS = 6000;

    /* Routes the Spring Boot backend deliberately does NOT implement yet.
       These stay owned by the mock, so a 404/405 (or the "No static
       resource" response Spring returns for unmapped paths) for one of them
       falls back to the mock instead of surfacing as an error. Every other
       route is expected to be live: a real backend error for those MUST NOT
       be hidden by a mock fallback. */
    var MOCK_ONLY_ROUTES = [
        { method: 'GET|PUT', pattern: /^\/courses\/[^/]+\/lessons\/[^/]+$/ },
        { method: 'GET|PUT', pattern: /^\/courses\/[^/]+\/prerequisites$/ },
        { method: 'GET|POST', pattern: /^\/courses\/[^/]+\/reviews$/ },
        { method: '*', pattern: /^\/quizzes\// },
        { method: '*', pattern: /^\/progress\// },
        { method: '*', pattern: /^\/certificates\// },
        { method: '*', pattern: /^\/notifications\// }
    ];

    function isAllowedMockRoute(method, path) {
        var m = String(method || 'GET').toUpperCase();
        var pathOnly = String(path || '').replace(/\?.*$/, '');

        return MOCK_ONLY_ROUTES.some(function (route) {
            if (route.method !== '*' && route.method.indexOf(m) === -1) {
                return false;
            }
            return route.pattern.test(pathOnly);
        });
    }

    /* The mock serving a request while the backend is (or may be) running is
       a strong signal that the requested endpoint is not implemented yet.
       Log it loudly so real errors are never silently hidden. */
    function warnMockServed(path, reason) {
        if (typeof console === 'object' && console.warn) {
            console.warn(
                '[Learnova] served "%s" from the local mock (%s). ' +
                'If the backend is reachable, this endpoint is not implemented yet.',
                path,
                reason
            );
        }
    }

    /* Once the backend is confirmed unreachable in this page session, mock
       requests (mock-owned routes and offline demo auth) skip the fetch and
       go straight to the mock. Live routes still always attempt the real
       backend. */
    var backendDown = false;

    function fetchWithTimeout(url, fetchOptions) {
        if (typeof AbortController === 'undefined') return fetch(url, fetchOptions);
        var controller = new AbortController();
        var timer = setTimeout(function () { controller.abort(); }, REQUEST_TIMEOUT_MS);
        return fetch(url, Object.assign({}, fetchOptions, { signal: controller.signal }))
            .then(function (response) {
                clearTimeout(timer);
                return response;
            }, function (err) {
                clearTimeout(timer);
                throw err;
            });
    }

    function request(path, options) {
        var opts = options || {};
        var mock = window.LearnovaMockAdapter;
        var useMock = false;

        var isAuthEntry = /\/auth\/(login|register)$/i.test(path);
        var isMockOnly = isAllowedMockRoute(opts.method || 'GET', path);

        /* The mock exists only to keep offline demo flows and the still
           mock-owned endpoints alive. Live routes (courses, catalogue,
           categories, enrollments, users, instructor, admin) ALWAYS hit the
           real backend so the frontend is genuinely data-driven by the
           database. */
        if (mock && typeof mock.handleRequest === 'function') {
            var hasMockSession = typeof mock.isMockSession === 'function' &&
                mock.isMockSession();

            if (isAuthEntry && hasMockSession) {
                /* Offline demo login: a mock-owned session only exists in the
                   mock's localStorage, so there is no backend session to
                   recover and the mock serves the login directly. */
                useMock = true;
            } else if (isMockOnly && (hasMockSession || backendDown)) {
                /* Fast path for mock-owned routes: a demo session or an
                   already confirmed-unreachable backend skips the fetch. */
                useMock = true;
            }
        }

        if (useMock) {
            warnMockServed(path, backendDown ? 'backend unreachable' : 'demo session');
            return Promise.resolve(mock.handleRequest(opts.method || 'GET', path, opts.body));
        }

        var headers = Object.assign({}, opts.headers || {});

        if (opts.body && typeof opts.body === 'object' && !(opts.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
            opts.body = JSON.stringify(opts.body);
        } else if (opts.body) {
            headers['Content-Type'] = 'application/json';
        }

        var user = LearnovaSession.currentUser();

        if (user && user.token) {
            headers['Authorization'] = /^Bearer\s+/i.test(user.token)
                ? user.token
                : 'Bearer ' + user.token;
        }

        return Promise.resolve().then(function () {
            return fetchWithTimeout(LearnovaConstants.API_BASE_URL + path, {
                method: opts.method || 'GET',
                headers: headers,
                body: opts.body
            });
        }).then(function (response) {
            return response.json().catch(function () {
                return {};
            }).then(function (data) {
                if (!response.ok) {
                    var message = (data && (data.message || data.detail || data.error)) ||
                        'Request failed with status ' + response.status;
                    var err = new Error(message);
                    err.status = response.status;
                    throw err;
                }
                return data;
            });
        }).catch(function (err) {
            var isNetworkError = !err || err.name === 'TypeError' || err.name === 'NetworkError' ||
                err.name === 'AbortError' ||
                /failed to fetch|network|timed out|abort/i.test(err.message || '');

            if (isNetworkError) backendDown = true;

            /* Only routes that are still mock-owned fall back on a missing
               backend handler (404/405 or the "No static resource" response
               Spring returns for unmapped paths). Live routes (courses,
               catalogue, categories, enrollments, users, instructor, admin)
               surface every error so the frontend is genuinely linked to the
               backend. Auth keeps its offline-demo fallback on pure network
               errors, but a rejected login/register always shows the real
               backend error rather than silently logging into a fake session. */
            var isMockOnlyRoute = isAllowedMockRoute(
                opts.method || 'GET',
                path
            );

            var isUnimplemented = isMockOnlyRoute && err && (
                err.status === 404 ||
                err.status === 405 ||
                (err.status === 500 &&
                    /no static resource|not implemented/i.test(err.message || ''))
            );

            var mayMock = isMockOnlyRoute &&
                (isNetworkError || isUnimplemented);

            if (isAuthEntry && isNetworkError) {
                mayMock = true;
            }

            if (mock &&
                typeof mock.handleRequest === 'function' &&
                mayMock) {
                warnMockServed(
                    path,
                    isUnimplemented ? 'not implemented by backend' : 'network error'
                );
                return mock.handleRequest(opts.method || 'GET', path, opts.body);
            }

            console.error('LearnovaApiClient.request error:', path, err);
            throw err;
        });
    }

    function get(path) {
        return request(path, { method: 'GET' });
    }

    function post(path, body) {
        return request(path, { method: 'POST', body: body });
    }

    function put(path, body) {
        return request(path, { method: 'PUT', body: body });
    }

    function del(path) {
        return request(path, { method: 'DELETE' });
    }

    return {
        request: request,
        get: get,
        post: post,
        put: put,
        del: del
    };
})();