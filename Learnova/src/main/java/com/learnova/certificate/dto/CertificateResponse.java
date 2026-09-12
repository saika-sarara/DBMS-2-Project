package com.learnova.certificate.dto;

import java.time.OffsetDateTime;

public record CertificateResponse(
        Long certificateId,
        Long userId,
        String type,
        Long courseId,
        Long trackId,
        String certCode,
        OffsetDateTime issuedAt,
        boolean alreadyIssued
) {
}