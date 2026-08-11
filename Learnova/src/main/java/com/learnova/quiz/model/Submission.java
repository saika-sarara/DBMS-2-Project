package com.learnova.quiz.model;

import java.time.OffsetDateTime;

public class Submission {
    private Long id;
    private Long userId;
    private Long quizId;
    private Double scorePct;
    private Boolean passed;
    private OffsetDateTime submittedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Long getQuizId() { return quizId; }
    public void setQuizId(Long quizId) { this.quizId = quizId; }
    public Double getScorePct() { return scorePct; }
    public void setScorePct(Double scorePct) { this.scorePct = scorePct; }
    public Boolean getPassed() { return passed; }
    public void setPassed(Boolean passed) { this.passed = passed; }
    public OffsetDateTime getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(OffsetDateTime submittedAt) { this.submittedAt = submittedAt; }
}
