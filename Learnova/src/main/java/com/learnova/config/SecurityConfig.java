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
    public SecurityFilterChain filterChain(
            HttpSecurity http
    ) throws Exception {

        http
                .csrf(csrf -> csrf.disable())

                .cors(Customizer.withDefaults())

                .sessionManagement(session ->
                        session.sessionCreationPolicy(
                                SessionCreationPolicy.STATELESS
                        )
                )

                .exceptionHandling(exception ->
                        exception
                                .authenticationEntryPoint(
                                        authenticationEntryPoint
                                )
                                .accessDeniedHandler(
                                        accessDeniedHandler
                                )
                )

                .authorizeHttpRequests(auth -> auth

                        /*
                         * Browser CORS preflight.
                         */
                        .requestMatchers(
                                HttpMethod.OPTIONS,
                                "/**"
                        )
                        .permitAll()


                        /*
                         * Authentication.
                         */
                        .requestMatchers(
                                HttpMethod.POST,
                                "/api/v1/auth/register",
                                "/api/v1/auth/login"
                        )
                        .permitAll()


                        /*
                         * API documentation.
                         */
                        .requestMatchers(
                                "/swagger-ui.html",
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/api-docs/**"
                        )
                        .permitAll()


                        /*
                         * Health endpoints.
                         */
                        .requestMatchers(
                                "/actuator/health",
                                "/actuator/info"
                        )
                        .permitAll()


                        /*
                         * Canonical public course-reading API.
                         *
                         * The old /api/v1/catalogue/** API has been removed.
                         */
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/v1/categories",
                                "/api/v1/courses",
                                "/api/v1/courses/**",
                                "/api/v1/lessons/**"
                        )
                        .permitAll()


                        /*
                         * Administrator domain.
                         */
                        .requestMatchers(
                                "/api/v1/admin/**"
                        )
                        .hasRole("ADMIN")


                        /*
                         * Enrollment statistics are administrative.
                         *
                         * This must appear before the general
                         * /api/v1/enrollments/** Student rule.
                         */
                        .requestMatchers(
                                "/api/v1/enrollments/stats"
                        )
                        .hasRole("ADMIN")


                        /*
                         * Instructor role request lifecycle.
                         */
                        .requestMatchers(
                                "/api/v1/instructor-requests/**"
                        )
                        .hasAnyRole(
                                "STUDENT",
                                "INSTRUCTOR",
                                "ADMIN"
                        )


                        /*
                         * Instructor authoring domain.
                         */
                        .requestMatchers(
                                "/api/v1/instructor/**"
                        )
                        .hasAnyRole(
                                "INSTRUCTOR",
                                "ADMIN"
                        )


                        /*
                         * Authenticated user/profile endpoints.
                         */
                        .requestMatchers(
                                "/api/v1/users/**"
                        )
                        .hasAnyRole(
                                "STUDENT",
                                "INSTRUCTOR",
                                "ADMIN"
                        )


                        /*
                         * Student enrollment operations.
                         */
                        .requestMatchers(
                                "/api/v1/enrollments/**"
                        )
                        .hasRole("STUDENT")


                        /*
                         * Student-specific endpoints, including the current
                         * lesson-quiz API.
                         */
                        .requestMatchers(
                                "/api/v1/student/**"
                        )
                        .hasRole("STUDENT")


                        /*
                         * Everything else must at least be authenticated.
                         */
                        .anyRequest()
                        .authenticated()
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

        /*
         * Development behavior retained for now.
         *
         * CORS hardening is handled later in the dedicated security phase.
         */
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