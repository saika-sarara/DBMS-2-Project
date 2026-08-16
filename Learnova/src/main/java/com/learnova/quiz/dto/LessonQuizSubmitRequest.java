package com.learnova.quiz.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public class LessonQuizSubmitRequest {

    @NotEmpty
    @Valid
    private List<LessonQuizAnswerDto> answers;

    private boolean bypass;

    public List<LessonQuizAnswerDto> getAnswers() { return answers; }
    public void setAnswers(List<LessonQuizAnswerDto> answers) { this.answers = answers; }

    public boolean isBypass() { return bypass; }
    public void setBypass(boolean bypass) { this.bypass = bypass; }
}
