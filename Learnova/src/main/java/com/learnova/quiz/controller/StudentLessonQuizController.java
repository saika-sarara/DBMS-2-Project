package com.learnova.quiz.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.LessonQuizQuestionDto;
import com.learnova.quiz.dto.LessonQuizStatusResponse;
import com.learnova.quiz.service.LessonQuizService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/student/quizzes")
@PreAuthorize("hasRole('STUDENT')")
public class StudentLessonQuizController {

    private final LessonQuizService service;

    public StudentLessonQuizController(
            LessonQuizService service
    ) {
        this.service = service;
    }

    @GetMapping("/lesson/{lesson}/status")
    public ResponseEntity<
            ApiResponse<LessonQuizStatusResponse>
    > status(
            @PathVariable String lesson,
            @RequestParam(
                    name = "bypass",
                    required = false,
                    defaultValue = "false"
            )
            boolean bypass,
            @RequestParam(
                    name = "course",
                    required = false
            )
            String course
    ) {

        LessonQuizStatusResponse response =
                service.getStatus(
                        lesson,
                        bypass,
                        course
                );

        return ResponseEntity.ok(
                ApiResponse.ok(response)
        );
    }

    @GetMapping("/lesson/{lesson}/random")
    public ResponseEntity<
            ApiResponse<List<LessonQuizQuestionDto>>
    > random(
            @PathVariable String lesson,
            @RequestParam(
                    name = "count",
                    required = false,
                    defaultValue = "5"
            )
            int count,
            @RequestParam(
                    name = "bypass",
                    required = false,
                    defaultValue = "false"
            )
            boolean bypass,
            @RequestParam(
                    name = "course",
                    required = false
            )
            String course
    ) {

        List<LessonQuizQuestionDto> questions =
                service.getQuestions(
                        lesson,
                        bypass,
                        count,
                        course
                );

        return ResponseEntity.ok(
                ApiResponse.ok(questions)
        );
    }
}