package com.learnova.quiz.dto;

public class LessonQuizCorrectAnswerDto {

    private Long id;
    private String correct;

    public LessonQuizCorrectAnswerDto() {}

    public LessonQuizCorrectAnswerDto(Long id, String correct) {
        this.id = id;
        this.correct = correct;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getCorrect() { return correct; }
    public void setCorrect(String correct) { this.correct = correct; }
}
