package com.learnova.quiz.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public class QuestionUpsertRequest {

    @NotBlank
    private String questionText;

    @NotEmpty
    private List<OptionInput> options;

    public QuestionUpsertRequest() {}

    public String getQuestionText() { return questionText; }
    public void setQuestionText(String questionText) { this.questionText = questionText; }
    public List<OptionInput> getOptions() { return options; }
    public void setOptions(List<OptionInput> options) { this.options = options; }
}
