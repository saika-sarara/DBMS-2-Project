package com.learnova.course.dto;

public record CourseSearchRequest(
        String search,
        Long categoryId,
        String difficulty,
        String sort,
        int page,
        int size
) {
}