package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record LessonResponse(
        Long lessonId,
        Long moduleId,
        Long courseId,
        String title,
        String description,
        Integer sequenceOrder,
        Integer estimatedDurationMinutes,
        boolean preview,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
