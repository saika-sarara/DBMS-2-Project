package com.learnova.quiz.dto;

import java.util.List;

public class LessonQuizBankQuestionDto {

    private Long id;
    private String text;
    private List<String> options;
    private String correct;

    public LessonQuizBankQuestionDto() {}

    public LessonQuizBankQuestionDto(Long id, String text, List<String> options, String correct) {
        this.id = id;
        this.text = text;
        this.options = options;
        this.correct = correct;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }

    public List<String> getOptions() { return options; }
    public void setOptions(List<String> options) { this.options = options; }

    public String getCorrect() { return correct; }
    public void setCorrect(String correct) { this.correct = correct; }
}
