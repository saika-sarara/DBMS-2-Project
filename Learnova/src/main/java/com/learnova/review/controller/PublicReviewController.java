package com.learnova.review.controller;

import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.review.dto.ReviewStateResponse;
import com.learnova.review.service.ReviewService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/courses")
public class PublicReviewController {

    private final ReviewService reviewService;
    private final CurrentUserResolver currentUserResolver;

    public PublicReviewController(ReviewService reviewService, CurrentUserResolver currentUserResolver) {
        this.reviewService = reviewService;
        this.currentUserResolver = currentUserResolver;
    }

    @GetMapping("/{courseId}/reviews")
    public ResponseEntity<ReviewStateResponse> getCourseReviews(@PathVariable Long courseId) {
        Long studentId = currentUserResolver.getCurrentUserIdOrNull();
        ReviewStateResponse response = reviewService.getReviewState(studentId, courseId);
        return ResponseEntity.ok(response);
    }
}