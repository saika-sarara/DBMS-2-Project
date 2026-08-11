package com.learnova.course.dto;

public record ContentBlockUpdateRequest(
        String title,
        String bodyMarkdown,
        String resourceUrl,
        Integer sequenceOrder
) {
}
