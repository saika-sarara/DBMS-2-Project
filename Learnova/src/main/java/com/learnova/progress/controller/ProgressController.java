package com.learnova.progress.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.quiz.dto.LessonQuizSubmitRequest;
import com.learnova.quiz.dto.LessonQuizSubmitResponse;
import com.learnova.quiz.service.LessonQuizService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/progress")
public class ProgressController {

	private final LessonQuizService lessonQuizService;

	public ProgressController(LessonQuizService lessonQuizService) {
		this.lessonQuizService = lessonQuizService;
	}

	@PostMapping("/{course}/lessons/{lesson}/quiz")
	@PreAuthorize("hasRole('STUDENT')")
	public ResponseEntity<ApiResponse<LessonQuizSubmitResponse>> submitLessonQuiz(
			@PathVariable String course,
			@PathVariable String lesson,
			@Valid @RequestBody LessonQuizSubmitRequest request
	) {
		LessonQuizSubmitResponse response = lessonQuizService.submit(
				lesson,
				request.isBypass(),
				request.getAnswers(),
				course
		);

		return ResponseEntity.ok(ApiResponse.ok(response));
	}
}
