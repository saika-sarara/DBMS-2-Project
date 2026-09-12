package com.learnova.config;

import com.learnova.security.AccessDeniedHandler;
import com.learnova.security.AuthenticationEntryPoint;
import com.learnova.security.JwtAuthenticationFilter;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.web.cors.DefaultCorsProcessor;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

class SecurityConfigTest {

    private static final String FRONTEND_ORIGIN = "http://localhost:3000";

    private final SecurityConfig securityConfig = new SecurityConfig(
            mock(JwtAuthenticationFilter.class),
            mock(AuthenticationEntryPoint.class),
            mock(AccessDeniedHandler.class)
    );

    @Test
    void allowsTheDocumentedFrontendOrigin() throws Exception {
        MockHttpServletRequest request = corsRequest("GET", FRONTEND_ORIGIN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        boolean processed = processCors(request, response);

        assertTrue(processed);
        assertEquals(FRONTEND_ORIGIN, response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        assertNull(response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS));
    }

    @Test
    void rejectsAnUnapprovedOrigin() throws Exception {
        MockHttpServletRequest request = corsRequest("GET", "http://evil.example");
        MockHttpServletResponse response = new MockHttpServletResponse();

        boolean processed = processCors(request, response);

        assertFalse(processed);
        assertEquals(403, response.getStatus());
        assertNull(response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @Test
    void preservesAllowedPreflightMethodsAndHeaders() throws Exception {
        MockHttpServletRequest request = corsRequest("OPTIONS", FRONTEND_ORIGIN);
        request.addHeader(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST");
        request.addHeader(
                HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS,
                "Authorization, Content-Type"
        );
        MockHttpServletResponse response = new MockHttpServletResponse();

        boolean processed = processCors(request, response);

        assertTrue(processed);
        assertEquals(FRONTEND_ORIGIN, response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        assertEquals(
            "GET,POST,PUT,PATCH,DELETE,OPTIONS",
                response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS)
        );
        assertEquals(
                "Authorization, Content-Type",
                response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS)
        );
        assertNull(response.getHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS));
    }

    private boolean processCors(
            MockHttpServletRequest request,
            MockHttpServletResponse response
    ) throws Exception {
        CorsConfigurationSource source = securityConfig.corsConfigurationSource();
        CorsConfiguration configuration = source.getCorsConfiguration(request);
        return new DefaultCorsProcessor().processRequest(configuration, request, response);
    }

    private MockHttpServletRequest corsRequest(String method, String origin) {
        MockHttpServletRequest request = new MockHttpServletRequest(method, "/api/v1/test");
        request.addHeader(HttpHeaders.ORIGIN, origin);
        return request;
    }
}
