/* ==========================================================================
   Learnova API Client (window.LearnovaApiClient)
   Thin fetch wrapper: JSON in/out, bearer auth from session, error throwing.
   ========================================================================== */

window.LearnovaApiClient = (function () {
    'use strict';

    var REQUEST_TIMEOUT_MS = 6000;

    /* Once the backend is confirmed unreachable in this page session, every
       request is routed straight to the mock instead of waiting for another
       timed-out fetch. */
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

        /* Auth entry points (login/register) always try the real backend first:
           a stale mock/demo session in localStorage must not keep sign-ups and
           sign-ins on the mock when the backend is reachable. They only fall
           back to the mock on network errors or rejected credentials. */
        var isAuthEntry = /\/auth\/(login|register)$/i.test(path);

        if (mock && typeof mock.handleRequest === 'function') {
            /* Fast path: a mock-owned session (demo token) only exists in the
               mock's localStorage, so skip the real backend for it. */
            if (!isAuthEntry &&
                typeof mock.isMockSession === 'function' &&
                mock.isMockSession()) {
                useMock = true;
            } else if (backendDown) {
                /* Fast path: the backend already timed out this session. */
                useMock = true;
            }
        }

        if (useMock) {
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

            /* The mock owns the demo accounts advertised on the login page.
               When the real backend is running but has no seeded/demo users,
               it rejects login/register with 401/403. Route auth endpoints
               that fail that way to the mock so the demo keeps working. */
            var isAuthRejection = err &&
                (err.status === 401 || err.status === 403) &&
                /\/auth\/(login|register)/i.test(path);

            /* The backend is built incrementally: auth + enrollments are live,
               the rest of the REST surface is still owned by the mock. When the
               backend is reachable but has no handler for this route (404, or
               the "No static resource" response it returns for unmapped paths),
               fall back to the mock so those modules keep working. */
            var isUnimplemented = err && (
                err.status === 404 ||
                (err.status === 500 && /no static resource|not implemented/i.test(err.message || ''))
            );

            if (isNetworkError) backendDown = true;

            if (mock &&
                typeof mock.handleRequest === 'function' &&
                (isNetworkError || isAuthRejection || isUnimplemented)) {
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