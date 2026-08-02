package com.learnova.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Spring Boot 4 auto-configures only the Jackson 3 mapper (tools.jackson).
 * The security layer (JWT claims, 401/403 JSON bodies) and jjwt-jackson are
 * built against Jackson 2 (com.fasterxml), so a dedicated bean is required.
 */
@Configuration
public class JacksonConfig {

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
}
