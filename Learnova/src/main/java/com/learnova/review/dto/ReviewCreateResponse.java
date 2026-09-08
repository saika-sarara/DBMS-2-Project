package com.learnova.review.dto;

import java.time.OffsetDateTime;

public record ReviewCreateResponse(
        Long reviewId,
        Long userId,
        Long courseId,
        Integer rating,
        String comment,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}