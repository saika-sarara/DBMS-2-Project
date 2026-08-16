package com.learnova.quiz.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.LessonQuizBankQuestionDto;
import com.learnova.quiz.dto.LessonQuizBankRequest;
import com.learnova.quiz.service.InstructorLessonQuizService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/quizzes")
public class InstructorLessonQuizController {

    private final InstructorLessonQuizService service;

    public InstructorLessonQuizController(InstructorLessonQuizService service) {
        this.service = service;
    }

    @GetMapping("/lesson/{lesson}")
    public ResponseEntity<ApiResponse<List<LessonQuizBankQuestionDto>>> list(
            @PathVariable String lesson,
            @RequestParam(name = "course", required = false) String course
    ) {
        List<LessonQuizBankQuestionDto> bank = service.getBank(lesson, course);
        return ResponseEntity.ok(ApiResponse.ok(bank));
    }

    @PostMapping("/lesson/{lesson}")
    public ResponseEntity<ApiResponse<Long>> create(
            @PathVariable String lesson,
            @RequestParam(name = "course", required = false) String course,
            @Valid @RequestBody LessonQuizBankRequest request
    ) {
        Long id = service.createQuestion(lesson, request, course);
        return ResponseEntity.ok(ApiResponse.ok("Question created", id));
    }

    @PutMapping("/{questionId}")
    public ResponseEntity<ApiResponse<Long>> update(
            @PathVariable Long questionId,
            @Valid @RequestBody LessonQuizBankRequest request
    ) {
        Long id = service.updateQuestion(questionId, request);
        return ResponseEntity.ok(ApiResponse.ok("Question updated", id));
    }

    @DeleteMapping("/{questionId}")
    public ResponseEntity<ApiResponse<Long>> remove(@PathVariable Long questionId) {
        Long id = service.deleteQuestion(questionId);
        return ResponseEntity.ok(ApiResponse.ok("Question deleted", id));
    }
}
