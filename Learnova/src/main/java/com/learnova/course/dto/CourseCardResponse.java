package com.learnova.course.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record CourseCardResponse(
        Long courseId,
        Long id,
        String title,
        String slug,
        String shortDescription,
        String thumbnailUrl,
        String difficulty,
        Long categoryId,
        String categoryName,
        BigDecimal avgRating,
        int reviewCount,
        OffsetDateTime publishedAt,
        double rankScore
) {
}