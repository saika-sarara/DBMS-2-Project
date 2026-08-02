/* ==========================================================================
   Learnova Profile (pages/common/profile.html)
   Loads the current user's profile through LearnovaProfileApi (/users/me),
   lets them update their name and password, and keeps the persisted session
   in sync so the navbar reflects the latest details.
   ========================================================================== */

(function () {
    'use strict';

    function splitName(fullName) {
        var parts = String(fullName || '').trim().split(/\s+/);
        return {
            first: parts[0] || '',
            last: parts.slice(1).join(' ')
        };
    }

    function initialsOf(name) {
        var parts = String(name || '').trim().split(/\s+/);
        return ((parts[0] || '')[0] || '') + ((parts[1] || '')[0] || '');
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function roleBadges(roles) {
        if (!Array.isArray(roles) || !roles.length) roles = ['Student'];
        return roles.map(function (role) {
            return '<span class="track-badge">' + esc(role) + '</span>';
        }).join('');
    }

    function applySessionRoles(user) {
        var roles = LearnovaSession.rolesOf(user);
        var primary = LearnovaSession.primaryRole() || (roles[0] || 'Account');
        var pill = document.getElementById('profileRoleLabel');
        if (pill) pill.textContent = primary;
    }

    function fill(profile) {
        var name = profile.fullName || profile.name || '';
        var roles = profile.roles || (profile.role ? [profile.role] : [LearnovaConstants.ROLES.STUDENT]);
        var status = profile.status || LearnovaConstants.ACCOUNT_STATUS.ACTIVE;

        setText('profileName', name || '—');
        setText('profileEmail', profile.email || '');
        setText('profileEmailDisplay', profile.email || '');

        var avatar = document.getElementById('profileAvatar');
        if (avatar) avatar.textContent = initialsOf(name) || '?';

        var badges = document.getElementById('profileBadges');
        if (badges) badges.innerHTML = roleBadges(roles);

        var statusBadge = document.getElementById('profileStatus');
        var statusLabel = { active: 'Active', suspended: 'Suspended', banned: 'Banned' }[status] || 'Active';
        if (statusBadge) statusBadge.innerHTML = '<span class="status-badge ' + esc(status) + '">' + statusLabel + '</span>';

        var parts = splitName(name);
        if (document.getElementById('profileFirstName')) document.getElementById('profileFirstName').value = parts.first;
        if (document.getElementById('profileLastName')) document.getElementById('profileLastName').value = parts.last;

        applySessionRoles(profile);
    }

    function setText(id, value) {
        var node = document.getElementById(id);
        if (node) node.textContent = value;
    }

    function load() {
        return LearnovaProfileApi.me().then(function (profile) {
            if (!profile) throw new Error('Profile could not be loaded.');
            fill(profile);

            var session = LearnovaSession.currentUser();
            if (session && profile.email) {
                var updated = Object.assign({}, session, {
                    name: profile.fullName || profile.name || session.name,
                    fullName: profile.fullName || session.fullName,
                    email: profile.email,
                    roles: profile.roles || session.roles,
                    role: profile.role || session.role,
                    status: profile.status || session.status
                });
                LearnovaSession.set(updated);
            }
            return profile;
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var backLink = document.getElementById('profileBackLink');
        if (backLink) {
            backLink.addEventListener('click', function () {
                LearnovaRouteGuard.redirectToDashboard();
            });
        }

        var infoForm = document.getElementById('profileInfoForm');
        if (infoForm) {
            infoForm.addEventListener('submit', function (event) {
                event.preventDefault();

                var firstName = document.getElementById('profileFirstName').value.trim();
                var lastName = document.getElementById('profileLastName').value.trim();

                if (!firstName && !lastName) {
                    LearnovaToast.error('Please enter at least one name field.');
                    return;
                }

                var current = LearnovaSession.currentUser() || {};
                var parts = splitName(current.fullName || current.name);
                var payload = {};
                if (firstName) payload.firstName = firstName;
                if (lastName) payload.lastName = lastName;

                LearnovaProfileApi.update(payload).then(function (profile) {
                    var session = Object.assign({}, LearnovaSession.currentUser(), {
                        name: profile.fullName || profile.name || (firstName + ' ' + lastName).trim(),
                        fullName: profile.fullName || profile.name || (firstName + ' ' + lastName).trim()
                    });
                    LearnovaSession.set(session);
                    LearnovaToast.success('Your profile has been updated.');
                    fill(profile);
                }).catch(function (err) {
                    LearnovaToast.error((err && err.message) || 'Could not update your profile.');
                });
            });
        }

        var passwordForm = document.getElementById('profilePasswordForm');
        if (passwordForm) {
            passwordForm.addEventListener('submit', function (event) {
                event.preventDefault();

                var currentPassword = document.getElementById('profileCurrentPassword').value;
                var newPassword = document.getElementById('profileNewPassword').value;
                var confirmPassword = document.getElementById('profileConfirmPassword').value;

                if (!currentPassword) {
                    LearnovaToast.error('Enter your current password.');
                    return;
                }
                if (String(newPassword).length < 8) {
                    LearnovaToast.error('New password must be at least 8 characters.');
                    return;
                }
                if (newPassword !== confirmPassword) {
                    LearnovaToast.error('The new passwords do not match.');
                    return;
                }

                LearnovaProfileApi.update({
                    currentPassword: currentPassword,
                    newPassword: newPassword
                }).then(function () {
                    passwordForm.reset();
                    LearnovaToast.success('Your password has been updated.');
                }).catch(function (err) {
                    LearnovaToast.error((err && err.message) || 'Could not update your password.');
                });
            });
        }

        load().catch(function (err) {
            LearnovaToast.error((err && err.message) || 'Could not load your profile.');
        });
    });
})();
