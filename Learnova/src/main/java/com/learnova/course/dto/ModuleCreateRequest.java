package com.learnova.course.dto;

public record ModuleCreateRequest(
        String title,
        String description,
        Integer sequenceOrder
) {
}
