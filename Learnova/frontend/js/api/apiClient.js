/* ==========================================================================
   Learnova API Client (window.LearnovaApiClient)
   Thin fetch wrapper: JSON in/out, bearer auth from session, error throwing.
   ========================================================================== */

window.LearnovaApiClient = (function () {
    'use strict';

    var REQUEST_TIMEOUT_MS = 6000;

    /* Explicit application mode. In 'MOCK' mode every request is served by
       the local mock (mock.js). In 'LIVE' mode (the default) the mock is never
       used: a missing backend route surfaces as a visible error instead of
       being silently hidden. Declared in LearnovaConstants.APP_MODE. */
    var APP_MODE = (typeof LearnovaConstants !== 'undefined' &&
        LearnovaConstants.APP_MODE)
        ? String(LearnovaConstants.APP_MODE).toUpperCase()
        : 'LIVE';
    var mockEnabled = APP_MODE === 'MOCK';

    /* Routes the Spring Boot backend deliberately does NOT implement yet.
       These are only relevant in 'MOCK' mode, where they are owned by the
       mock. In 'LIVE' mode they must hit the real backend and surface a real
       error if the endpoint does not exist — never a silent mock fallback. */
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

    /* The mock serving a request is only possible in explicit 'MOCK' mode.
       In 'LIVE' mode this should never be reached; log loudly so a real
       error is never silently hidden. */
    function warnMockServed(path, reason) {
        if (typeof console === 'object' && console.warn) {
            console.warn(
                '[Learnova] served "%s" from the local mock (%s). ' +
                'This only happens in APP_MODE=MOCK.',
                path,
                reason
            );
        }
    }

    /* Once the backend is confirmed unreachable in a 'MOCK' session, mock
       requests skip the fetch and go straight to the mock. Only meaningful in
       'MOCK' mode; 'LIVE' mode always attempts the real backend. */
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

        /* The mock is used ONLY in explicit 'MOCK' mode (APP_MODE=MOCK).
           In 'LIVE' mode every request hits the real backend; unimplemented
           routes surface real errors instead of a silent mock fallback. */
        if (mockEnabled && mock && typeof mock.handleRequest === 'function') {
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

            /* In 'LIVE' mode there is no mock fallback at all: every request
               must reach the real backend, and unimplemented routes surface
               their error. In 'MOCK' mode, mock-owned routes fall back on the
               local mock when the backend handler is missing or unreachable,
               and offline auth keeps its demo fallback on pure network
               errors (a rejected login/register always shows the real backend
               error rather than silently logging into a fake session). */
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

            var mayMock = mockEnabled &&
                isMockOnlyRoute &&
                (isNetworkError || isUnimplemented);

            if (mockEnabled && isAuthEntry && isNetworkError) {
                mayMock = true;
            }

            if (mockEnabled &&
                mock &&
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