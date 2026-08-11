package com.learnova.course.dto;

public record LessonUpdateRequest(
        String title,
        String description,
        Integer sequenceOrder,
        Integer estimatedDurationMinutes,
        Boolean isPreview
) {
}
