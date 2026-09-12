package com.learnova.security;

import com.learnova.config.SecurityConfig;
import com.learnova.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.security.web.FilterChainProxy;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.ArgumentMatchers.any;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringJUnitConfig(RbacSecurityIntegrationTest.TestApplication.class)
@WebAppConfiguration
class RbacSecurityIntegrationTest {

    private final WebApplicationContext applicationContext;
    private MockMvc mockMvc;

    RbacSecurityIntegrationTest(WebApplicationContext applicationContext) {
        this.applicationContext = applicationContext;
    }

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(applicationContext)
            .addFilters(applicationContext.getBean(FilterChainProxy.class))
                .apply(springSecurity())
                .build();
    }

    @Test
    @WithMockUser(roles = "STUDENT")
    void studentCanAccessStudentEndpointButNotInstructorOrAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/enrollments/probe"))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/instructor/probe"))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/admin/probe"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "INSTRUCTOR")
    void instructorCanAccessInstructorEndpointButNotStudentOrAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/instructor/probe"))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/enrollments/probe"))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/admin/probe"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanAccessAdminAndInstructorEndpointsButNotStudentOnlyEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/admin/probe"))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/instructor/probe"))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/enrollments/probe"))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedRequestIsRejected() throws Exception {
        mockMvc.perform(get("/api/v1/admin/probe"))
                .andExpect(status().isUnauthorized());
    }

    @RestController
    static class RbacProbeController {

        @GetMapping("/api/v1/enrollments/probe")
        String studentEndpoint() {
            return "student";
        }

        @GetMapping("/api/v1/instructor/probe")
        String instructorEndpoint() {
            return "instructor";
        }

        @GetMapping("/api/v1/admin/probe")
        String adminEndpoint() {
            return "admin";
        }
    }

    @Configuration(proxyBeanMethods = false)
    @EnableWebMvc
    @EnableWebSecurity
    @Import(SecurityConfig.class)
    static class TestApplication {

        @Bean
        RbacProbeController rbacProbeController() {
            return new RbacProbeController();
        }

        @Bean
        JwtAuthenticationFilter jwtAuthenticationFilter() {
            return new JwtAuthenticationFilter(mock(JwtService.class), mock(UserRepository.class));
        }

        @Bean
        AuthenticationEntryPoint authenticationEntryPoint() throws Exception {
            AuthenticationEntryPoint handler = mock(AuthenticationEntryPoint.class);
            doAnswer(invocation -> {
                invocation.getArgument(1, HttpServletResponse.class).setStatus(401);
                return null;
            }).when(handler).commence(any(), any(), any());
            return handler;
        }

        @Bean
        AccessDeniedHandler accessDeniedHandler() throws Exception {
            AccessDeniedHandler handler = mock(AccessDeniedHandler.class);
            doAnswer(invocation -> {
                invocation.getArgument(1, HttpServletResponse.class).setStatus(403);
                return null;
            }).when(handler).handle(any(), any(), any());
            return handler;
        }
    }
}
