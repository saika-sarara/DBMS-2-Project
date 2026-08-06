package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record ContentBlockResponse(
        Long blockId,
        Long lessonId,
        String blockType,
        String title,
        String bodyMarkdown,
        String resourceUrl,
        Integer sequenceOrder,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
