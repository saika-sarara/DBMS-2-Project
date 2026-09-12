package com.learnova.enrollment.support;

import com.learnova.common.exception.UnauthorizedActionException;
import com.learnova.security.UserPrincipal;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class CurrentUserResolverTest {

    private final CurrentUserResolver resolver = new CurrentUserResolver();

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void resolvesUserIdFromLightweightPrincipal() {
        UserPrincipal principal = new UserPrincipal(5L, "ACTIVE", Set.of("STUDENT"));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        principal,
                        null,
                        principal.getAuthorities()
                )
        );

        assertEquals(5L, resolver.getCurrentUserId());
        assertEquals(5L, resolver.getCurrentUserIdOrNull());
    }

    @Test
    void resolvesUserIdFromNumericPrincipal() {
        SecurityContextHolder.getContext().setAuthentication(
            UsernamePasswordAuthenticationToken.authenticated(42L, null, List.of())
        );

        assertEquals(42L, resolver.getCurrentUserId());
    }

    @Test
    void returnsNullWhenAnonymousAndThrowsForRequiredUserId() {
        assertNull(resolver.getCurrentUserIdOrNull());
        assertThrows(UnauthorizedActionException.class, resolver::getCurrentUserId);
    }
}