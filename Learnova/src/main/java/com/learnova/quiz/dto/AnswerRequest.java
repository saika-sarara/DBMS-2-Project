package com.learnova.quiz.dto;

import jakarta.validation.constraints.NotNull;

public class AnswerRequest {
    @NotNull
    private Long selectedOptionId;

    public Long getSelectedOptionId() { return selectedOptionId; }
    public void setSelectedOptionId(Long selectedOptionId) { this.selectedOptionId = selectedOptionId; }
}
