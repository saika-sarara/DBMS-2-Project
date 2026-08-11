package com.learnova.course.dto;

public record CourseCreateRequest(
        Long categoryId,
        String title,
        String shortDescription,
        String description,
        String difficulty,
        String thumbnailUrl
) {
}
