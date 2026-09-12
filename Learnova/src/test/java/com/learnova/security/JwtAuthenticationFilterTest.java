package com.learnova.security;

import com.learnova.user.dto.UserAuthView;
import com.learnova.user.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtService jwtService;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void validJwtAuthenticatesTheRequestedUserWithExactAuthorities() throws Exception {
        when(jwtService.validateAndGetUserId("valid-token")).thenReturn(5L);
        when(userRepository.findAuthViewsByUserId(5L)).thenReturn(List.of(
                firstRow(5L, "ACTIVE"),
                roleRow("INSTRUCTOR"),
                roleRow("STUDENT")
        ));

        HttpServletRequest request = requestWithBearer("valid-token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response);

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(authentication);
        assertTrue(authentication.isAuthenticated());

        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        assertEquals(5L, principal.getId());
        assertEquals(
                Set.of("ROLE_INSTRUCTOR", "ROLE_STUDENT"),
                principal.getAuthorities()
                        .stream()
                        .map(GrantedAuthority::getAuthority)
                        .collect(Collectors.toSet())
        );

        verify(userRepository).findAuthViewsByUserId(5L);
    }

    @Test
    void validJwtWithoutRolesAuthenticatesWithEmptyAuthorities() throws Exception {
        when(jwtService.validateAndGetUserId("valid-token")).thenReturn(6L);
        when(userRepository.findAuthViewsByUserId(6L)).thenReturn(List.of(
                firstRow(6L, "ACTIVE")
        ));

        HttpServletRequest request = requestWithBearer("valid-token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(authentication);
        assertTrue(authentication.isAuthenticated());

        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        assertEquals(6L, principal.getId());
        assertEquals(Set.of(), principal.getAuthorities());
    }

    @Test
    void nonexistentUserIsNotAuthenticated() throws Exception {
        when(jwtService.validateAndGetUserId("token")).thenReturn(7L);
        when(userRepository.findAuthViewsByUserId(7L)).thenReturn(List.of());

        HttpServletRequest request = requestWithBearer("token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    void inactiveUserIsNotAuthenticated() throws Exception {
        when(jwtService.validateAndGetUserId("token")).thenReturn(8L);
        when(userRepository.findAuthViewsByUserId(8L)).thenReturn(List.of(
                firstRow(8L, "SUSPENDED")
        ));

        HttpServletRequest request = requestWithBearer("token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    void invalidJwtClearsContextAndContinuesWithoutDatabaseLookup() throws Exception {
        when(jwtService.validateAndGetUserId("bad-token")).thenReturn(null);

        HttpServletRequest request = requestWithBearer("bad-token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(userRepository, never()).findAuthViewsByUserId(anyLong());
    }

    @Test
    void missingBearerHeaderContinuesWithoutDatabaseLookup() throws Exception {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader(HttpHeaders.AUTHORIZATION)).thenReturn("Basic abc");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(userRepository, never()).findAuthViewsByUserId(anyLong());
    }

    @Test
    void authenticationUsesSingleProjectionQueryWithoutPerRoleLookup() throws Exception {
        when(jwtService.validateAndGetUserId("token")).thenReturn(5L);
        when(userRepository.findAuthViewsByUserId(5L)).thenReturn(List.of(
                firstRow(5L, "ACTIVE"),
                roleRow("A"),
                roleRow("B")
        ));

        HttpServletRequest request = requestWithBearer("token");
        HttpServletResponse response = mock(HttpServletResponse.class);
        FilterChain chain = mock(FilterChain.class);

        jwtAuthenticationFilter.doFilterInternal(request, response, chain);

        verify(userRepository, times(1)).findAuthViewsByUserId(5L);
        verifyNoMoreInteractions(userRepository);
    }

    private HttpServletRequest requestWithBearer(String token) {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader(HttpHeaders.AUTHORIZATION)).thenReturn("Bearer " + token);
        return request;
    }

    private UserAuthView firstRow(Long id, String accountStatus) {
        return new TestUserAuthView(id, accountStatus, null);
    }

    private UserAuthView roleRow(String roleName) {
        return new TestUserAuthView(null, null, roleName);
    }

    private static final class TestUserAuthView implements UserAuthView {

        private final Long id;
        private final String accountStatus;
        private final String roleName;

        private TestUserAuthView(Long id, String accountStatus, String roleName) {
            this.id = id;
            this.accountStatus = accountStatus;
            this.roleName = roleName;
        }

        @Override
        public Long getId() {
            return id;
        }

        @Override
        public String getAccountStatus() {
            return accountStatus;
        }

        @Override
        public String getRoleName() {
            return roleName;
        }
    }
}