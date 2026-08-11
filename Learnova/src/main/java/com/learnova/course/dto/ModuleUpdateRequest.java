package com.learnova.course.dto;

public record ModuleUpdateRequest(
        String title,
        String description,
        Integer sequenceOrder
) {
}
