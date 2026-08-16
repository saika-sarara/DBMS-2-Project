package com.learnova.quiz.dto;

public class LessonQuizStatusResponse {

    private boolean passed;
    private int used;
    private int attemptsLeft;
    private int limit;
    private boolean exhausted;

    public LessonQuizStatusResponse() {}

    public LessonQuizStatusResponse(boolean passed, int used, int attemptsLeft, int limit, boolean exhausted) {
        this.passed = passed;
        this.used = used;
        this.attemptsLeft = attemptsLeft;
        this.limit = limit;
        this.exhausted = exhausted;
    }

    public boolean isPassed() { return passed; }
    public void setPassed(boolean passed) { this.passed = passed; }

    public int getUsed() { return used; }
    public void setUsed(int used) { this.used = used; }

    public int getAttemptsLeft() { return attemptsLeft; }
    public void setAttemptsLeft(int attemptsLeft) { this.attemptsLeft = attemptsLeft; }

    public int getLimit() { return limit; }
    public void setLimit(int limit) { this.limit = limit; }

    public boolean isExhausted() { return exhausted; }
    public void setExhausted(boolean exhausted) { this.exhausted = exhausted; }
}
