package com.learnova.review.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.review.dto.ReviewCreateRequest;
import com.learnova.review.dto.ReviewCreateResponse;
import com.learnova.review.dto.ReviewStateResponse;
import com.learnova.review.repository.ReviewRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final ObjectMapper objectMapper;

    public ReviewService(ReviewRepository reviewRepository, ObjectMapper objectMapper) {
        this.reviewRepository = reviewRepository;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public ReviewStateResponse getReviewState(Long studentId, Long courseId) {
        ReviewRepository.ReviewStateRow row = reviewRepository.findReviewState(studentId, courseId);
        if (row == null) {
            return null;
        }

        try {
            ReviewStateResponse.OwnReview ownReview = row.ownReviewJson() != null
                    ? objectMapper.readValue(row.ownReviewJson(), ReviewStateResponse.OwnReview.class)
                    : null;

            List<ReviewStateResponse.Review> reviews = objectMapper.readValue(
                    row.reviewsJson(),
                    objectMapper.getTypeFactory().constructCollectionType(List.class, ReviewStateResponse.Review.class)
            );

            return new ReviewStateResponse(
                    row.courseId(),
                    row.avgRating(),
                    row.reviewCount(),
                    row.reviewState(),
                    row.canReview(),
                    ownReview,
                    reviews
            );
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Error parsing review JSON data", e);
        }
    }

    @Transactional
    public ReviewCreateResponse createReview(Long studentId, Long courseId, ReviewCreateRequest request) {
        ReviewRepository.CreatedReviewRow row = reviewRepository.createReview(
                studentId,
                courseId,
                request.rating(),
                request.comment()
        );

        return new ReviewCreateResponse(
                row.reviewId(),
                row.userId(),
                row.courseId(),
                row.rating(),
                row.comment(),
                row.createdAt(),
                row.updatedAt()
        );
    }
}