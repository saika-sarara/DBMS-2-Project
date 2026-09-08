package com.learnova.review.dto;

import java.math.BigDecimal;
import java.util.List;

public record ReviewStateResponse(
        Long courseId,
        BigDecimal avgRating,
        int reviewCount,
        String reviewState,
        boolean canReview,
        OwnReview ownReview,
        List<Review> reviews
) {
    public ReviewStateResponse {
        reviews = reviews == null ? List.of() : List.copyOf(reviews);
    }
    public record OwnReview(
            Long reviewId,
            Integer rating,
            String comment,
            String createdAt
    ) {}

    public record Review(
            Long reviewId,
            Integer rating,
            String comment,
            String reviewerName,
            String createdAt
    ) {}
}