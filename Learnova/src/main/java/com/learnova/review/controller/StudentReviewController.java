package com.learnova.review.controller;

import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.review.dto.ReviewCreateRequest;
import com.learnova.review.dto.ReviewCreateResponse;
import com.learnova.review.service.ReviewService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/student/courses")
public class StudentReviewController {

    private final ReviewService reviewService;
    private final CurrentUserResolver currentUserResolver;

    public StudentReviewController(ReviewService reviewService, CurrentUserResolver currentUserResolver) {
        this.reviewService = reviewService;
        this.currentUserResolver = currentUserResolver;
    }

    @PostMapping("/{courseId}/reviews")
    public ResponseEntity<ReviewCreateResponse> createReview(
            @PathVariable Long courseId,
            @Valid @RequestBody ReviewCreateRequest request
    ) {
        Long studentId = currentUserResolver.getCurrentUserId();
        ReviewCreateResponse response = reviewService.createReview(studentId, courseId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}