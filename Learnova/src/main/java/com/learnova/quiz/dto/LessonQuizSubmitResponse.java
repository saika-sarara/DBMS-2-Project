package com.learnova.quiz.dto;

import java.util.List;

public class LessonQuizSubmitResponse {

    private Double score;
    private boolean passed;
    private boolean alreadyPassed;
    private int attemptsLeft;
    private boolean exhausted;
    private List<LessonQuizCorrectAnswerDto> correctAnswers;

    public LessonQuizSubmitResponse() {}

    public LessonQuizSubmitResponse(Double score, boolean passed, boolean alreadyPassed,
                                    int attemptsLeft, boolean exhausted,
                                    List<LessonQuizCorrectAnswerDto> correctAnswers) {
        this.score = score;
        this.passed = passed;
        this.alreadyPassed = alreadyPassed;
        this.attemptsLeft = attemptsLeft;
        this.exhausted = exhausted;
        this.correctAnswers = correctAnswers;
    }

    public Double getScore() { return score; }
    public void setScore(Double score) { this.score = score; }

    public boolean isPassed() { return passed; }
    public void setPassed(boolean passed) { this.passed = passed; }

    public boolean isAlreadyPassed() { return alreadyPassed; }
    public void setAlreadyPassed(boolean alreadyPassed) { this.alreadyPassed = alreadyPassed; }

    public int getAttemptsLeft() { return attemptsLeft; }
    public void setAttemptsLeft(int attemptsLeft) { this.attemptsLeft = attemptsLeft; }

    public boolean isExhausted() { return exhausted; }
    public void setExhausted(boolean exhausted) { this.exhausted = exhausted; }

    public List<LessonQuizCorrectAnswerDto> getCorrectAnswers() { return correctAnswers; }
    public void setCorrectAnswers(List<LessonQuizCorrectAnswerDto> correctAnswers) { this.correctAnswers = correctAnswers; }
}
