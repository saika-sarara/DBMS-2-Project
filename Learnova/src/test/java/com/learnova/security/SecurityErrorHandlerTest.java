package com.learnova.security;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.common.response.ApiResponse;
import com.learnova.config.JacksonConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SecurityErrorHandlerTest {

    private ObjectMapper objectMapper;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        objectMapper = new JacksonConfig().objectMapper();
        request = new MockHttpServletRequest();
    }

    @Test
    void authenticationEntryPointReturnsSerializable401Response() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();

        new AuthenticationEntryPoint(objectMapper).commence(
                request,
                response,
                new BadCredentialsException("invalid")
        );

        JsonNode body = objectMapper.readTree(response.getContentAsByteArray());
        assertEquals(401, response.getStatus());
        assertEquals("application/json", response.getContentType());
        assertEquals(false, body.get("success").asBoolean());
        assertEquals("Authentication is required.", body.get("message").asText());
        assertNotNull(body.get("timestamp"));
        assertTrue(isSerializedTimestamp(body.get("timestamp")));
    }

    @Test
    void accessDeniedHandlerReturnsSerializable403Response() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();

        new AccessDeniedHandler(objectMapper).handle(
                request,
                response,
                new AccessDeniedException("denied")
        );

        JsonNode body = objectMapper.readTree(response.getContentAsByteArray());
        assertEquals(403, response.getStatus());
        assertEquals("application/json", response.getContentType());
        assertEquals(false, body.get("success").asBoolean());
        assertEquals(
                "You do not have permission to access this resource.",
                body.get("message").asText()
        );
        assertNotNull(body.get("timestamp"));
        assertTrue(isSerializedTimestamp(body.get("timestamp")));
    }

    @Test
    void productionMapperSerializesApiResponseTimestamp() throws Exception {
        String json = objectMapper.writeValueAsString(ApiResponse.error("test"));

        JsonNode body = objectMapper.readTree(json);
        assertEquals(false, body.get("success").asBoolean());
        assertEquals("test", body.get("message").asText());
        assertTrue(isSerializedTimestamp(body.get("timestamp")));
    }

    private boolean isSerializedTimestamp(JsonNode timestamp) {
        return timestamp.isTextual() || timestamp.isNumber();
    }
}