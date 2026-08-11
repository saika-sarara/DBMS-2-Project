package com.learnova.course.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record CourseDetailsResponse(
        Long courseId,
        String title,
        String slug,
        String shortDescription,
        String description,
        String difficulty,
        String thumbnailUrl,
        Long categoryId,
        String categoryName,
        Long instructorId,
        String instructorName,
        java.math.BigDecimal avgRating,
        int reviewCount,
        int totalLessons,
        int estimatedDurationMinutes,
        long totalModules,
        OffsetDateTime publishedAt,
        OffsetDateTime createdAt,
        String cardStatus,
        boolean locked,
        boolean enrolled,
        boolean completed,
        String lockReason,
        List<String> tags
) {
    public CourseDetailsResponse {
        tags = List.copyOf(tags);
    }
}
