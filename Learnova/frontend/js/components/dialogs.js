/* ==========================================================================
   Learnova UI Dialogs (window.LearnovaToast, window.LearnovaConfirm)
   Pretty toast notifications and a promise-based confirm modal that replace
   the native alert() / confirm() popups. Styling is injected once on first
   use, so pages only need to include this script.
   ========================================================================== */

(function () {
    'use strict';

    /* ---------- Injected styles ---------- */

    var STYLE_ID = 'learnova-dialogs-css';

    function injectStyles() {
        if (document.getElementById(STYLE_ID)) return;
        var style = document.createElement('style');
        style.id = STYLE_ID;
        style.textContent =
            '#learnova-toast-container{position:fixed;top:1.25rem;right:1.25rem;z-index:2000;' +
                'display:flex;flex-direction:column;gap:0.75rem;max-width:min(380px,calc(100vw - 2.5rem));}' +
            '.learnova-toast{display:flex;align-items:flex-start;gap:0.75rem;background:#fff;color:#2b2b40;' +
                'border-radius:10px;padding:0.85rem 1rem;box-shadow:0 10px 30px rgba(24,0,173,0.16);' +
                'border-left:4px solid #1800ad;font-size:0.98rem;line-height:1.45;' +
                'opacity:0;transform:translateX(16px);transition:opacity 0.22s ease,transform 0.22s ease;}' +
            '.learnova-toast.learnova-toast-visible{opacity:1;transform:translateX(0);}' +
            '.learnova-toast.learnova-toast-leaving{opacity:0;transform:translateX(16px);}' +
            '.learnova-toast i{margin-top:0.15rem;font-size:1.15rem;color:#1800ad;flex:none;}' +
            '.learnova-toast-success{border-left-color:#1e9e50;}.learnova-toast-success i{color:#1e9e50;}' +
            '.learnova-toast-error{border-left-color:#d7263d;}.learnova-toast-error i{color:#d7263d;}' +
            '.learnova-toast-message{flex:1;word-break:break-word;}' +
            '.learnova-toast-close{background:none;border:none;cursor:pointer;color:#9a9ab0;' +
                'font-size:1.25rem;line-height:1;padding:0 0.1rem;flex:none;}' +
            '.learnova-toast-close:hover{color:#1800ad;}' +
            '.learnova-confirm-overlay{position:fixed;inset:0;background:rgba(24,0,173,0.4);' +
                'display:flex;align-items:center;justify-content:center;z-index:1500;padding:1.5rem;}' +
            '.learnova-confirm-modal{background:#fff;border-radius:12px;padding:1.75rem 2rem;' +
                'max-width:440px;width:100%;box-shadow:0 12px 40px rgba(24,0,173,0.18);' +
                'animation:learnova-confirm-pop 0.18s ease-out;}' +
            '@keyframes learnova-confirm-pop{from{transform:scale(0.96);opacity:0;}to{transform:scale(1);opacity:1;}}' +
            '.learnova-confirm-title{margin:0 0 0.6rem;font-size:1.5rem;font-weight:700;color:#1800ad;}' +
            '.learnova-confirm-body{margin:0 0 1.5rem;color:#5f5f7a;line-height:1.6;font-size:1.02rem;}' +
            '.learnova-confirm-actions{display:flex;justify-content:flex-end;gap:0.75rem;}' +
            '.learnova-confirm-actions button{font-family:inherit;padding:0.55rem 1.25rem;border-radius:6px;' +
                'font-size:1rem;cursor:pointer;transition:background 0.2s ease,color 0.2s ease,border-color 0.2s ease;}' +
            '.learnova-confirm-cancel{background:#fff;border:2px solid #d8dcf0;color:#3a3a52;}' +
            '.learnova-confirm-cancel:hover{border-color:#1800ad;color:#1800ad;}' +
            '.learnova-confirm-ok{background:#1800ad;border:2px solid #1800ad;color:#fff;}' +
            '.learnova-confirm-ok:hover{background:#2400c4;border-color:#2400c4;}' +
            '.learnova-prompt-input{width:100%;padding:0.6rem 0.75rem;border:2px solid #d8dcf0;' +
                'border-radius:6px;font-size:1rem;font-family:inherit;color:#2b2b40;margin-bottom:1.25rem;}' +
            '.learnova-prompt-input:focus{outline:none;border-color:#1800ad;}';
        document.head.appendChild(style);
    }

    /* ---------- Toasts ---------- */

    var ICONS = {
        success: 'fa-circle-check',
        error: 'fa-circle-xmark',
        info: 'fa-circle-info'
    };

    window.LearnovaToast = {
        show: function (message, type) {
            injectStyles();
            var kind = ICONS[type] ? type : 'info';
            var container = document.getElementById('learnova-toast-container');
            if (!container) {
                container = document.createElement('div');
                container.id = 'learnova-toast-container';
                document.body.appendChild(container);
            }

            var toast = document.createElement('div');
            toast.className = 'learnova-toast learnova-toast-' + kind;
            toast.setAttribute('role', 'status');

            var icon = document.createElement('i');
            icon.className = 'fa-solid ' + ICONS[kind];

            var text = document.createElement('span');
            text.className = 'learnova-toast-message';
            text.textContent = message || '';

            var close = document.createElement('button');
            close.className = 'learnova-toast-close';
            close.type = 'button';
            close.setAttribute('aria-label', 'Dismiss');
            close.innerHTML = '&times;';
            close.addEventListener('click', function () {
                dismiss(toast);
            });

            toast.appendChild(icon);
            toast.appendChild(text);
            toast.appendChild(close);
            container.appendChild(toast);

            requestAnimationFrame(function () {
                toast.classList.add('learnova-toast-visible');
            });

            var timer = setTimeout(function () {
                dismiss(toast);
            }, 4500);
            toast.dataset.timer = timer;

            return toast;
        },
        info: function (message) { return this.show(message, 'info'); },
        success: function (message) { return this.show(message, 'success'); },
        error: function (message) { return this.show(message, 'error'); }
    };

    function dismiss(toast) {
        if (!toast || toast.classList.contains('learnova-toast-leaving')) return;
        clearTimeout(Number(toast.dataset.timer) || 0);
        toast.classList.add('learnova-toast-leaving');
        setTimeout(function () {
            if (toast.parentNode) toast.parentNode.removeChild(toast);
        }, 220);
    }

    /* ---------- Confirm / prompt modal ---------- */

    function openModal(opts) {
        injectStyles();
        return new Promise(function (resolve) {
            var overlay = document.createElement('div');
            overlay.className = 'learnova-confirm-overlay';

            var modal = document.createElement('div');
            modal.className = 'learnova-confirm-modal';
            modal.setAttribute('role', 'dialog');
            modal.setAttribute('aria-modal', 'true');

            var title = document.createElement('h3');
            title.className = 'learnova-confirm-title';
            title.textContent = opts.title || 'Are you sure?';

            var body = document.createElement('p');
            body.className = 'learnova-confirm-body';
            body.textContent = opts.message || '';

            var input = null;
            if (opts.input) {
                input = document.createElement('input');
                input.className = 'learnova-prompt-input';
                input.type = 'text';
                input.value = opts.defaultValue || '';
            }

            var actions = document.createElement('div');
            actions.className = 'learnova-confirm-actions';

            var cancelBtn = document.createElement('button');
            cancelBtn.className = 'learnova-confirm-cancel';
            cancelBtn.type = 'button';
            cancelBtn.textContent = opts.cancelLabel || 'Cancel';

            var okBtn = document.createElement('button');
            okBtn.className = 'learnova-confirm-ok';
            okBtn.type = 'button';
            okBtn.textContent = opts.confirmLabel || 'Confirm';

            actions.appendChild(cancelBtn);
            actions.appendChild(okBtn);

            modal.appendChild(title);
            modal.appendChild(body);
            if (input) modal.appendChild(input);
            modal.appendChild(actions);
            overlay.appendChild(modal);
            document.body.appendChild(overlay);

            function done(result) {
                if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
                document.removeEventListener('keydown', onKey, true);
                resolve(result);
            }

            function onKey(event) {
                if (event.key === 'Escape') {
                    done(opts.input ? null : false);
                } else if (event.key === 'Enter') {
                    if (!opts.input) {
                        done(true);
                    } else if (input.value.trim()) {
                        done(input.value.trim());
                    }
                }
            }

            cancelBtn.addEventListener('click', function () {
                done(opts.input ? null : false);
            });
            okBtn.addEventListener('click', function () {
                if (opts.input) {
                    done(input.value.trim() || null);
                } else {
                    done(true);
                }
            });
            overlay.addEventListener('click', function (event) {
                if (event.target === overlay) done(opts.input ? null : false);
            });
            document.addEventListener('keydown', onKey, true);

            if (input) {
                input.focus();
                input.select();
            } else {
                okBtn.focus();
            }
        });
    }

    window.LearnovaConfirm = {
        ask: function (message, options) {
            var opts = options || {};
            return openModal({
                title: opts.title || 'Are you sure?',
                message: message,
                input: false,
                confirmLabel: opts.confirmLabel,
                cancelLabel: opts.cancelLabel
            });
        }
    };

    window.LearnovaPrompt = {
        ask: function (message, options) {
            var opts = options || {};
            return openModal({
                title: opts.title || 'Enter a value',
                message: message,
                input: true,
                defaultValue: opts.defaultValue,
                confirmLabel: opts.confirmLabel || 'OK',
                cancelLabel: opts.cancelLabel
            });
        }
    };
})();
