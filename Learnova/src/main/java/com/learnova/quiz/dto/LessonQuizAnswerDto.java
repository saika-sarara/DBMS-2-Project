package com.learnova.quiz.dto;

public class LessonQuizAnswerDto {

    private Long id;
    private String selected;

    public LessonQuizAnswerDto() {}

    public LessonQuizAnswerDto(Long id, String selected) {
        this.id = id;
        this.selected = selected;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getSelected() { return selected; }
    public void setSelected(String selected) { this.selected = selected; }
}
