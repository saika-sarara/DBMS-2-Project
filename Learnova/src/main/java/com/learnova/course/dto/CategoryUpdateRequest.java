package com.learnova.course.dto;

public record CategoryUpdateRequest(
        String name,
        String description,
        Boolean isActive
) {
}
