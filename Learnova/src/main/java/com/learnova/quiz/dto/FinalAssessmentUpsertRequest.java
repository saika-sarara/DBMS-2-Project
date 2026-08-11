package com.learnova.quiz.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public class FinalAssessmentUpsertRequest {

    @NotBlank
    private String title;

    @NotNull
    @Min(0)
    @Max(100)
    private Double passingScore;

    @NotNull
    @Min(1)
    private Integer dailyAttemptLimit;

    private Boolean isActive = true;

    public FinalAssessmentUpsertRequest() {
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public Double getPassingScore() {
        return passingScore;
    }

    public void setPassingScore(Double passingScore) {
        this.passingScore = passingScore;
    }

    public Integer getDailyAttemptLimit() {
        return dailyAttemptLimit;
    }

    public void setDailyAttemptLimit(Integer dailyAttemptLimit) {
        this.dailyAttemptLimit = dailyAttemptLimit;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean active) {
        isActive = active;
    }
}
