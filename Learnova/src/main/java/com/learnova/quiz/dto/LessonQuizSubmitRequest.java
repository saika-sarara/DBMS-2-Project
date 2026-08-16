package com.learnova.quiz.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public class LessonQuizSubmitRequest {

    @NotEmpty(
            message = "Answers are required"
    )
    @Size(
            min = 1,
            max = 20,
            message = "Invalid number of quiz answers"
    )
    @Valid
    private List<LessonQuizAnswerDto> answers;

    /*
     * Temporary compatibility field.
     *
     * This will be removed when bypass assessment
     * receives its own endpoint.
     */
    private boolean bypass;

    public LessonQuizSubmitRequest() {}

    public List<LessonQuizAnswerDto> getAnswers() {
        return answers;
    }

    public void setAnswers(
            List<LessonQuizAnswerDto> answers
    ) {
        this.answers = answers;
    }

    public boolean isBypass() {
        return bypass;
    }

    public void setBypass(
            boolean bypass
    ) {
        this.bypass = bypass;
    }
}