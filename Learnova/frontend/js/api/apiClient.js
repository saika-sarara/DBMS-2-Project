/* ==========================================================================
   Learnova API Client (window.LearnovaApiClient)
   Thin fetch wrapper: JSON in/out, bearer auth from session, error throwing.
   ========================================================================== */

window.LearnovaApiClient = (function () {
    'use strict';

    function request(path, options) {
        var opts = options || {};
        var headers = Object.assign({}, opts.headers || {});

        /* Serialize JSON bodies; skip stringifying FormData (let the browser set the boundary). */
        if (opts.body && typeof opts.body === 'object' && !(opts.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
            opts.body = JSON.stringify(opts.body);
        } else if (opts.body) {
            headers['Content-Type'] = 'application/json';
        }

        var user = LearnovaSession.currentUser();
        if (user && user.token) {
            headers['Authorization'] = 'Bearer ' + user.token;
        }

        return fetch(LearnovaConstants.API_BASE_URL + path, {
            method: opts.method || 'GET',
            headers: headers,
            body: opts.body
        }).then(function (response) {
            return response.json().catch(function () {
                return {};
            }).then(function (data) {
                if (!response.ok) {
                    var message = (data && (data.message || data.detail || data.error)) ||
                        'Request failed with status ' + response.status;
                    throw new Error(message);
                }
                return data;
            });
        }).catch(function (err) {
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
