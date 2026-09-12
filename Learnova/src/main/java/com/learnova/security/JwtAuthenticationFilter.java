package com.learnova.security;

import com.learnova.user.dto.UserAuthView;
import com.learnova.user.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            UserRepository userRepository
    ) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String authorizationHeader = request.getHeader(HttpHeaders.AUTHORIZATION);

        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authorizationHeader.substring(7).trim();
        Long userId = jwtService.validateAndGetUserId(token);

        if (userId == null) {
            SecurityContextHolder.clearContext();
            filterChain.doFilter(request, response);
            return;
        }

        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            List<UserAuthView> authViews = userRepository.findAuthViewsByUserId(userId);

            if (!authViews.isEmpty()) {
                UserAuthView firstRow = authViews.get(0);

                if ("ACTIVE".equalsIgnoreCase(firstRow.getAccountStatus())) {
                    authenticateRequest(firstRow, authViews, request);
                }
            }
        }

        filterChain.doFilter(request, response);
    }

    private void authenticateRequest(
            UserAuthView firstRow,
            List<UserAuthView> authViews,
            HttpServletRequest request
    ) {
        Set<String> roleNames = authViews.stream()
                .map(UserAuthView::getRoleName)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        UserPrincipal principal = new UserPrincipal(
                firstRow.getId(),
                firstRow.getAccountStatus(),
                roleNames
        );

        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                        principal,
                        null,
                        principal.getAuthorities()
                );

        authentication.setDetails(
                new WebAuthenticationDetailsSource().buildDetails(request)
        );

        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}