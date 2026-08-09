package com.learnova.quiz.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.AnswerRequest;
import com.learnova.quiz.dto.StudentAttemptResponse;
import com.learnova.quiz.dto.SubmissionResponse;
import com.learnova.quiz.service.StudentAssessmentService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/student")
public class StudentAssessmentController {

    private final StudentAssessmentService service;

    public StudentAssessmentController(StudentAssessmentService service) {
        this.service = service;
    }

    @GetMapping("/courses/{courseId}/final-assessment/status")
    public ResponseEntity<ApiResponse<Map<String, Object>>> status(@PathVariable Long courseId) {
        Map<String, Object> status = service.getStatusForCourse(courseId);
        return ResponseEntity.ok(ApiResponse.ok(status));
    }

    @PostMapping("/courses/{courseId}/final-assessment/attempts")
    public ResponseEntity<ApiResponse<StudentAttemptResponse>> startAttempt(@PathVariable Long courseId) {
        StudentAttemptResponse resp = service.startAttempt(courseId);
        return ResponseEntity.ok(ApiResponse.ok(resp));
    }

    @GetMapping("/final-assessment/attempts/{attemptId}")
    public ResponseEntity<ApiResponse<StudentAttemptResponse>> getAttempt(@PathVariable Long attemptId) {
        // Not implemented separately here.
        return ResponseEntity.badRequest().body(ApiResponse.error("Not implemented"));
    }

    @PutMapping("/final-assessment/attempts/{attemptId}/answers/{questionId}")
    public ResponseEntity<ApiResponse<Void>> saveAnswer(
            @PathVariable Long attemptId,
            @PathVariable Long questionId,
            @Valid @RequestBody AnswerRequest req
    ) {
        service.saveAnswer(attemptId, questionId, req.getSelectedOptionId());
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @PostMapping("/final-assessment/attempts/{attemptId}/submit")
    public ResponseEntity<ApiResponse<SubmissionResponse>> submitAttempt(@PathVariable Long attemptId) {
        SubmissionResponse resp = service.submitAttempt(attemptId);
        return ResponseEntity.ok(ApiResponse.ok(resp));
    }

    @GetMapping("/courses/{courseId}/final-assessment/history")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> history(@PathVariable Long courseId) {
        List<Map<String, Object>> hist = (List<Map<String, Object>>) (Object) service.historyForCourse(courseId);
        return ResponseEntity.ok(ApiResponse.ok(hist));
    }
}
