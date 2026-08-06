package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record AdminCourseResponse(
        Long courseId,
        String title,
        String slug,
        String status,
        String difficulty,
        Long categoryId,
        String categoryName,
        Long instructorId,
        String instructorName,
        String shortDescription,
        String description,
        String thumbnailUrl,
        long moduleCount,
        long lessonCount,
        String rejectionReason,
        OffsetDateTime submittedAt,
        OffsetDateTime publishedAt,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
