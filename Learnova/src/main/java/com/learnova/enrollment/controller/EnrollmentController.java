package com.learnova.enrollment.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.enrollment.dto.EnrollmentAccessResponse;
import com.learnova.enrollment.dto.EnrollmentRequest;
import com.learnova.enrollment.dto.EnrollmentResponse;
import com.learnova.enrollment.dto.EnrollmentStatsResponse;
import com.learnova.enrollment.service.EnrollmentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/enrollments")
@CrossOrigin(origins = "*")
public class EnrollmentController {

    private final EnrollmentService enrollmentService;

    public EnrollmentController(EnrollmentService enrollmentService) {
        this.enrollmentService = enrollmentService;
    }

    @PostMapping("/courses/{courseId}")
    public ResponseEntity<ApiResponse<EnrollmentResponse>> enrollInCourse(@PathVariable Long courseId) {
        EnrollmentResponse response = enrollmentService.enrollInCourse(
                new EnrollmentRequest(courseId, null, "standalone")
        );
        return ResponseEntity.ok(ApiResponse.ok("Enrollment successful", response));
    }

    @PostMapping("/tracks/{trackId}")
    public ResponseEntity<ApiResponse<EnrollmentResponse>> enrollInTrack(@PathVariable Long trackId) {
        EnrollmentResponse response = enrollmentService.enrollInTrack(
                new EnrollmentRequest(null, trackId, "track")
        );
        return ResponseEntity.ok(ApiResponse.ok("Enrollment successful", response));
    }

    @GetMapping("/my-courses")
    public ResponseEntity<ApiResponse<List<EnrollmentResponse>>> getMyCourses() {
        return ResponseEntity.ok(ApiResponse.ok(enrollmentService.getMyCourses()));
    }

    @GetMapping("/my-tracks")
    public ResponseEntity<ApiResponse<List<EnrollmentResponse>>> getMyTracks() {
        return ResponseEntity.ok(ApiResponse.ok(enrollmentService.getMyTracks()));
    }

    @GetMapping("/courses/{courseId}/access")
    public ResponseEntity<ApiResponse<EnrollmentAccessResponse>> getCourseAccess(@PathVariable Long courseId) {
        return ResponseEntity.ok(ApiResponse.ok(enrollmentService.getCourseAccess(courseId)));
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<EnrollmentStatsResponse>> getStats() {
        return ResponseEntity.ok(ApiResponse.ok(enrollmentService.getAdminStats()));
    }
}
