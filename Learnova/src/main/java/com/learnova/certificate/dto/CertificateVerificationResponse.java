package com.learnova.certificate.dto;

import java.time.OffsetDateTime;

public record CertificateVerificationResponse(
        Long certificateId,
        String certCode,
        String type,
        String holderName,
        String entityTitle,
        OffsetDateTime issuedAt
) {
}