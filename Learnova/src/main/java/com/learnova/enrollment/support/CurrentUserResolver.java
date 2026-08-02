package com.learnova.enrollment.support;

import com.learnova.common.exception.UnauthorizedActionException;
import com.learnova.security.UserPrincipal;
import com.learnova.user.model.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component
public class CurrentUserResolver {

    public Long getCurrentUserId() {
        Long userId = resolveFromSecurityContext();

        if (userId == null) {
            throw new UnauthorizedActionException("You must be logged in.");
        }

        return userId;
    }

    private Long resolveFromSecurityContext() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        if (authentication == null || !authentication.isAuthenticated()) {
            return null;
        }

        Object principal = authentication.getPrincipal();

        if (principal instanceof UserPrincipal userPrincipal) {
            return userPrincipal.getId();
        }

        if (principal instanceof User user) {
            return user.getId();
        }

        if (principal instanceof Number number) {
            return number.longValue();
        }

        String name = authentication.getName();

        if (name != null && !name.isBlank()) {
            try {
                return Long.parseLong(name);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }

        return null;
    }
}