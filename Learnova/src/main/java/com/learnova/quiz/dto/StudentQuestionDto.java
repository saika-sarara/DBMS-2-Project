package com.learnova.quiz.dto;

import java.util.List;

public class StudentQuestionDto {
    private Long questionId;
    private Integer displayOrder;
    private String questionText;
    private List<StudentOptionDto> options;

    public StudentQuestionDto() {}

    public StudentQuestionDto(Long questionId, Integer displayOrder, String questionText, List<StudentOptionDto> options) {
        this.questionId = questionId;
        this.displayOrder = displayOrder;
        this.questionText = questionText;
        this.options = options;
    }

    public Long getQuestionId() { return questionId; }
    public void setQuestionId(Long questionId) { this.questionId = questionId; }
    public Integer getDisplayOrder() { return displayOrder; }
    public void setDisplayOrder(Integer displayOrder) { this.displayOrder = displayOrder; }
    public String getQuestionText() { return questionText; }
    public void setQuestionText(String questionText) { this.questionText = questionText; }
    public List<StudentOptionDto> getOptions() { return options; }
    public void setOptions(List<StudentOptionDto> options) { this.options = options; }
}
