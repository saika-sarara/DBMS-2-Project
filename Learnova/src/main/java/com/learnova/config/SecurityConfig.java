package com.learnova.config;

import com.learnova.security.AccessDeniedHandler;
import com.learnova.security.AuthenticationEntryPoint;
import com.learnova.security.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final AuthenticationEntryPoint authenticationEntryPoint;
    private final AccessDeniedHandler accessDeniedHandler;

    public SecurityConfig(
            JwtAuthenticationFilter jwtAuthenticationFilter,
            AuthenticationEntryPoint authenticationEntryPoint,
            AccessDeniedHandler accessDeniedHandler
    ) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.authenticationEntryPoint = authenticationEntryPoint;
        this.accessDeniedHandler = accessDeniedHandler;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(session ->
                        session.sessionCreationPolicy(
                                SessionCreationPolicy.STATELESS
                        )
                )
                .exceptionHandling(exception -> exception
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler)
                )
                .authorizeHttpRequests(auth -> auth

                        // Allow browser CORS preflight requests
                        .requestMatchers(
                                HttpMethod.OPTIONS,
                                "/**"
                        ).permitAll()

                        // Public authentication endpoints
                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/auth/register",
                                "/api/v1/auth/login"
                        ).permitAll()

                        // Public API documentation
                        .requestMatchers(
                                "/swagger-ui.html",
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/api-docs/**"
                        ).permitAll()

                        // Public application health endpoints
                        .requestMatchers(
                                "/actuator/health",
                                "/actuator/info"
                        ).permitAll()

                        // Public course catalogue endpoints
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/catalogue/categories",
                                "/api/v1/catalogue/courses",
                                "/api/v1/categories"
                        ).permitAll()

                        // Existing public course-reading endpoints
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/courses/**"
                        ).permitAll()

                        // Public lesson-content endpoint. PostgreSQL owns
                        // the access decision (preview / enrolled / owner).
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/lessons/**"
                        ).permitAll()

                        // Administrator-only endpoints
                        .requestMatchers(
                                "/api/v1/admin/**"
                        ).hasRole("ADMIN")

                        .requestMatchers(
                                "/api/v1/enrollments/stats"
                        ).hasRole("ADMIN")

                        // Student, instructor and administrator endpoints
                        .requestMatchers(
                                "/api/v1/instructor-requests/**"
                        ).hasAnyRole(
                                "STUDENT",
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        // Instructor course authoring endpoints
                        .requestMatchers(
                                "/api/v1/instructor/**"
                        ).hasAnyRole(
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        .requestMatchers(
                                "/api/v1/users/**"
                        ).hasAnyRole(
                                "STUDENT",
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        // Student-only enrollment endpoints
                        .requestMatchers(
                                "/api/v1/enrollments/**"
                        ).hasRole("STUDENT")

                        // Instructor and administrator course management
                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/courses/**"
                        ).hasAnyRole(
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        .requestMatchers(
                                HttpMethod.PUT,
                                "/api/v1/courses/**"
                        ).hasAnyRole(
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        .requestMatchers(
                                HttpMethod.DELETE,
                                "/api/v1/courses/**"
                        ).hasAnyRole(
                                "INSTRUCTOR",
                                "ADMIN"
                        )

                        .requestMatchers(
                            HttpMethod.GET,
                            "/api/v1/catalogue/categories"
                        ).permitAll()

                        .requestMatchers(
                             "/api/v1/admin/categories",
                            "/api/v1/admin/categories/**"
                         ).hasRole("ADMIN")

                        // Student-only final assessment endpoints
                        .requestMatchers(
                            "/api/v1/student/**",
                            "/api/v1/student/courses/*/final-assessment/**",
                            "/api/v1/student/final-assessment/**"
                        ).hasRole("STUDENT")

                        // Every other endpoint requires authentication
                        .anyRequest().authenticated()
                )
                .addFilterBefore(
                        jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class
                );

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration =
                new CorsConfiguration();

        configuration.setAllowedOriginPatterns(
                List.of("*")
        );

        configuration.setAllowedMethods(
                List.of(
                        "GET",
                        "POST",
                        "PUT",
                        "PATCH",
                        "DELETE",
                        "OPTIONS"
                )
        );

        configuration.setAllowedHeaders(
                List.of("*")
        );

        configuration.setExposedHeaders(
                List.of("Authorization")
        );

        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source =
                new UrlBasedCorsConfigurationSource();

        source.registerCorsConfiguration(
                "/**",
                configuration
        );

        return source;
    }
}
