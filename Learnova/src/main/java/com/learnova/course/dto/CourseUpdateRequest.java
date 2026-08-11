package com.learnova.course.dto;

public record CourseUpdateRequest(
        Long categoryId,
        String title,
        String shortDescription,
        String description,
        String difficulty,
        String thumbnailUrl
) {
}
