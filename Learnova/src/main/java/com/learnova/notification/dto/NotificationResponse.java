package com.learnova.notification.dto;

import java.time.OffsetDateTime;

public record NotificationResponse(
        Long id,
        String message,
        boolean read,
        String relatedEntityType,
        Long relatedEntityId,
        OffsetDateTime createdAt
) {
}
