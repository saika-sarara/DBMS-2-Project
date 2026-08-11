package com.learnova.course.dto;

public record LessonContentBlockResponse(
        Long blockId,
        Long lessonId,
        String blockType,
        String title,
        String bodyMarkdown,
        String resourceUrl,
        Integer sequenceOrder
) {
}
