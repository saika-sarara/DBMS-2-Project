package com.learnova.course.dto;

public record ContentBlockCreateRequest(
        String blockType,
        String title,
        String bodyMarkdown,
        String resourceUrl,
        Integer sequenceOrder
) {
}
