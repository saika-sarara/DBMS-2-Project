package com.learnova.quiz.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.FinalAssessmentUpsertRequest;
import com.learnova.quiz.dto.QuestionUpsertRequest;
import com.learnova.quiz.service.InstructorAssessmentService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/instructor")
public class InstructorAssessmentController {

    private final InstructorAssessmentService service;

    public InstructorAssessmentController(InstructorAssessmentService service) {
        this.service = service;
    }

    @PutMapping("/courses/{courseId}/final-assessment")
    public ResponseEntity<ApiResponse<Long>> upsertAssessment(
            @PathVariable Long courseId,
            @Valid @RequestBody FinalAssessmentUpsertRequest req
    ) {
        Long id = service.upsertFinalAssessment(courseId, req);
        return ResponseEntity.ok(ApiResponse.ok("Assessment upserted", id));
    }

    @PostMapping("/final-assessments/{assessmentId}/questions")
    public ResponseEntity<ApiResponse<Long>> addQuestion(
            @PathVariable Long assessmentId,
            @Valid @RequestBody QuestionUpsertRequest req
    ) {
        Long qid = service.addQuestion(assessmentId, req);
        return ResponseEntity.ok(ApiResponse.ok("Question added", qid));
    }
}
