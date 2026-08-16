package com.learnova.quiz.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public class LessonQuizBankRequest {

    @NotBlank
    private String text;

    @NotEmpty
    @Size(min = 2, max = 6)
    private List<String> options;

    @NotBlank
    @Pattern(regexp = "^[A-Fa-f]$", message = "correct must be a single letter A-F")
    private String correct;

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }

    public List<String> getOptions() { return options; }
    public void setOptions(List<String> options) { this.options = options; }

    public String getCorrect() { return correct; }
    public void setCorrect(String correct) { this.correct = correct; }
}
