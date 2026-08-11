package com.learnova.quiz.dto;

import java.time.OffsetDateTime;

public class SubmissionResponse {
    private Long attemptId;
    private Double scorePct;
    private Double passingScore;
    private Boolean passed;
    private Boolean courseCompleted;
    private OffsetDateTime submittedAt;
    private String message;

    public SubmissionResponse() {}

    public Long getAttemptId() { return attemptId; }
    public void setAttemptId(Long attemptId) { this.attemptId = attemptId; }
    public Double getScorePct() { return scorePct; }
    public void setScorePct(Double scorePct) { this.scorePct = scorePct; }
    public Double getPassingScore() { return passingScore; }
    public void setPassingScore(Double passingScore) { this.passingScore = passingScore; }
    public Boolean getPassed() { return passed; }
    public void setPassed(Boolean passed) { this.passed = passed; }
    public Boolean getCourseCompleted() { return courseCompleted; }
    public void setCourseCompleted(Boolean courseCompleted) { this.courseCompleted = courseCompleted; }
    public OffsetDateTime getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(OffsetDateTime submittedAt) { this.submittedAt = submittedAt; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
