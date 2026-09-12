package com.learnova.certificate.model;

import java.time.OffsetDateTime;

public record Certificate(
        Long id,
        Long userId,
        String type,
        Long courseId,
        Long trackId,
        String certCode,
        OffsetDateTime issuedAt
) {
}