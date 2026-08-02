package com.learnova.security;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class JwtService {

    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private final String secret;
    private final long expirationMs;
    private final ObjectMapper objectMapper;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.expiration}") long expirationMs,
            ObjectMapper objectMapper
    ) {
        this.secret = secret;
        this.expirationMs = expirationMs;
        this.objectMapper = objectMapper;
    }

    public String generateToken(User user) {
        try {
            long now = Instant.now().toEpochMilli();
            long expiry = now + expirationMs;

            Set<String> roles = user.getRoles()
                    .stream()
                    .map(Role::getName)
                    .collect(Collectors.toSet());

            Map<String, Object> header = new LinkedHashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("sub", String.valueOf(user.getId()));
            payload.put("email", user.getEmail());
            payload.put("roles", roles);
            payload.put("iat", now);
            payload.put("exp", expiry);

            String encodedHeader = encodeJson(header);
            String encodedPayload = encodeJson(payload);
            String unsignedToken = encodedHeader + "." + encodedPayload;
            String signature = sign(unsignedToken);

            return unsignedToken + "." + signature;
        } catch (Exception exception) {
            throw new IllegalStateException("Could not generate JWT token.", exception);
        }
    }

    public Long validateAndGetUserId(String token) {
        try {
            Map<String, Object> claims = parseAndValidate(token);

            Object subject = claims.get("sub");
            if (subject == null) {
                return null;
            }

            return Long.parseLong(String.valueOf(subject));
        } catch (Exception exception) {
            return null;
        }
    }

    private Map<String, Object> parseAndValidate(String token) throws Exception {
        String[] parts = token.split("\\.");

        if (parts.length != 3) {
            throw new IllegalArgumentException("Invalid JWT format.");
        }

        String unsignedToken = parts[0] + "." + parts[1];
        String expectedSignature = sign(unsignedToken);

        if (!constantTimeEquals(expectedSignature, parts[2])) {
            throw new IllegalArgumentException("Invalid JWT signature.");
        }

        byte[] payloadBytes = Base64.getUrlDecoder().decode(parts[1]);

        Map<String, Object> claims = objectMapper.readValue(
                payloadBytes,
                new TypeReference<Map<String, Object>>() {}
        );

        Object exp = claims.get("exp");
        if (exp == null) {
            throw new IllegalArgumentException("Missing JWT expiration.");
        }

        long expiry = Long.parseLong(String.valueOf(exp));

        if (Instant.now().toEpochMilli() > expiry) {
            throw new IllegalArgumentException("JWT token expired.");
        }

        return claims;
    }

    private String encodeJson(Map<String, Object> value) throws Exception {
        byte[] jsonBytes = objectMapper.writeValueAsBytes(value);

        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(jsonBytes);
    }

    private String sign(String unsignedToken) throws Exception {
        Mac mac = Mac.getInstance(HMAC_ALGORITHM);
        SecretKeySpec key = new SecretKeySpec(
                secret.getBytes(StandardCharsets.UTF_8),
                HMAC_ALGORITHM
        );
        mac.init(key);

        byte[] signatureBytes = mac.doFinal(unsignedToken.getBytes(StandardCharsets.UTF_8));

        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(signatureBytes);
    }

    private boolean constantTimeEquals(String expected, String actual) {
        byte[] expectedBytes = expected.getBytes(StandardCharsets.UTF_8);
        byte[] actualBytes = actual.getBytes(StandardCharsets.UTF_8);

        if (expectedBytes.length != actualBytes.length) {
            return false;
        }

        int result = 0;

        for (int i = 0; i < expectedBytes.length; i++) {
            result |= expectedBytes[i] ^ actualBytes[i];
        }

        return result == 0;
    }
}