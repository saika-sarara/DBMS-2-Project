package com.learnova.review.controller;

import com.learnova.review.dto.ReviewCreateRequest;
import com.learnova.review.dto.ReviewCreateResponse;
import com.learnova.review.service.ReviewService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/student/courses")
public class StudentReviewController {

    private final ReviewService reviewService;

    public StudentReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @PostMapping("/{courseId}/reviews")
    public ResponseEntity<ReviewCreateResponse> createReview(
            @PathVariable Long courseId,
            @RequestHeader("X-Student-Id") Long studentId,
            @RequestBody ReviewCreateRequest request
    ) {
        ReviewCreateResponse response = reviewService.createReview(studentId, courseId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}