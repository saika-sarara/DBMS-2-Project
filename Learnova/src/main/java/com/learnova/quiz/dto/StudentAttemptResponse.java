package com.learnova.quiz.dto;

import java.time.OffsetDateTime;
import java.util.List;

public class StudentAttemptResponse {
    private Long attemptId;
    private Long quizId;
    private Long enrollmentId;
    private Integer attemptNo;
    private OffsetDateTime startedAt;
    private List<StudentQuestionDto> questions;

    public StudentAttemptResponse() {}

    public Long getAttemptId() { return attemptId; }
    public void setAttemptId(Long attemptId) { this.attemptId = attemptId; }
    public Long getQuizId() { return quizId; }
    public void setQuizId(Long quizId) { this.quizId = quizId; }
    public Long getEnrollmentId() { return enrollmentId; }
    public void setEnrollmentId(Long enrollmentId) { this.enrollmentId = enrollmentId; }
    public Integer getAttemptNo() { return attemptNo; }
    public void setAttemptNo(Integer attemptNo) { this.attemptNo = attemptNo; }
    public OffsetDateTime getStartedAt() { return startedAt; }
    public void setStartedAt(OffsetDateTime startedAt) { this.startedAt = startedAt; }
    public List<StudentQuestionDto> getQuestions() { return questions; }
    public void setQuestions(List<StudentQuestionDto> questions) { this.questions = questions; }
}
