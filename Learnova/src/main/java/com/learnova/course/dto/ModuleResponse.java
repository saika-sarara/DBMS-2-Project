package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record ModuleResponse(
        Long moduleId,
        Long courseId,
        String title,
        String description,
        Integer sequenceOrder,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
