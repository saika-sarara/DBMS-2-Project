package com.learnova.review.controller;

import com.learnova.review.dto.ReviewStateResponse;
import com.learnova.review.service.ReviewService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/courses")
public class PublicReviewController {

    private final ReviewService reviewService;

    public PublicReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @GetMapping("/{courseId}/reviews")
    public ResponseEntity<ReviewStateResponse> getCourseReviews(
            @PathVariable Long courseId,
            @RequestParam(required = false) Long studentId
    ) {
        ReviewStateResponse response = reviewService.getReviewState(studentId, courseId);
        return ResponseEntity.ok(response);
    }
}