package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record AdminCategoryResponse(
        Long id,
        String name,
        String slug,
        String description,
        boolean active,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
