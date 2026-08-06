package com.learnova.course.dto;

public record LessonCreateRequest(
        String title,
        String description,
        Integer sequenceOrder,
        Integer estimatedDurationMinutes,
        Boolean isPreview
) {
}
