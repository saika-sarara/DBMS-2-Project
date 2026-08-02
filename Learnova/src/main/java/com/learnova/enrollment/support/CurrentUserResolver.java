package com.learnova.enrollment.support;

import com.learnova.common.exception.UnauthorizedActionException;
import com.learnova.user.model.User;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * Resolves the current user id for enrollment requests.
 *
 * Resolution order:
 *   1. A real Spring Security principal (once auth is wired).
 *   2. The X-User-Id (or X-Demo-User) request header. The auth module is
 *      still a stub, so every real request must identify itself with the
 *      header until JWT login lands.
 */
@Component
public class CurrentUserResolver {

    private static final String USER_ID_HEADER = "X-User-Id";
    private static final String DEMO_USER_HEADER = "X-Demo-User";

    private final HttpServletRequest request;

    public CurrentUserResolver(HttpServletRequest request) {
        this.request = request;
    }

    public Long getCurrentUserId() {
        Long userId = resolveFromSecurityContext();
        if (userId != null) {
            return userId;
        }
        userId = resolveFromHeader();
        if (userId != null) {
            return userId;
        }
        throw new UnauthorizedActionException("You must be logged in to enroll.");
    }

    private Long resolveFromSecurityContext() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            return null;
        }
        Object principal = authentication.getPrincipal();
        if (principal instanceof User user) {
            return user.getId();
        }
        if (principal instanceof Number number) {
            return number.longValue();
        }
        if (principal instanceof String username) {
            try {
                return Long.parseLong(username);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private Long resolveFromHeader() {
        String header = request.getHeader(USER_ID_HEADER);
        if (header == null || header.isBlank()) {
            header = request.getHeader(DEMO_USER_HEADER);
        }
        if (header != null && !header.isBlank()) {
            try {
                return Long.parseLong(header.trim());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }
}
