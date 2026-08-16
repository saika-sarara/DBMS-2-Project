package com.learnova.quiz.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.LessonQuizSubmitRequest;
import com.learnova.quiz.dto.LessonQuizSubmitResponse;
import com.learnova.quiz.service.LessonQuizService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/progress")
@PreAuthorize("hasRole('STUDENT')")
public class ProgressController {

    private final LessonQuizService service;

    public ProgressController(
            LessonQuizService service
    ) {
        this.service = service;
    }

    @PostMapping(
            "/{course}/lessons/{lesson}/quiz"
    )
    public ResponseEntity<
            ApiResponse<LessonQuizSubmitResponse>
    > submitQuizAttempt(
            @PathVariable String course,
            @PathVariable String lesson,
            @Valid
            @RequestBody
            LessonQuizSubmitRequest request
    ) {

        LessonQuizSubmitResponse response =
                service.submit(
                        lesson,
                        request.isBypass(),
                        request.getAnswers(),
                        course
                );

        return ResponseEntity.ok(
                ApiResponse.ok(response)
        );
    }
}