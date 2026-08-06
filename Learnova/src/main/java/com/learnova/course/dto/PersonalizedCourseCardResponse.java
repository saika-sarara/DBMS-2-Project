package com.learnova.course.dto;

import java.math.BigDecimal;

public record PersonalizedCourseCardResponse(
        Long courseId,
        String title,
        String slug,
        String shortDescription,
        String thumbnailUrl,
        String difficulty,
        Long categoryId,
        String categoryName,
        BigDecimal avgRating,
        int reviewCount,
        int totalLessons,
        int estimatedDurationMinutes,
        Long instructorId,
        String instructorName,
        String cardStatus,
        boolean locked,
        boolean enrolled,
        boolean completed,
        String lockReason,
        double rankScore
) {
}
