package com.learnova.quiz.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public class LessonQuizBankRequest {

    @NotBlank(
            message = "Question text is required"
    )
    @Size(
            max = 2000,
            message = "Question text cannot exceed 2000 characters"
    )
    private String text;

    @NotNull(
            message = "Options are required"
    )
    @Size(
            min = 4,
            max = 4,
            message = "A quiz question must contain exactly four options"
    )
    private List<
            @NotBlank(
                    message = "Quiz options cannot be blank"
            )
            @Size(
                    max = 1000,
                    message = "A quiz option cannot exceed 1000 characters"
            )
            String
    > options;

    @NotBlank(
            message = "Correct answer is required"
    )
    @Pattern(
            regexp = "^[A-Da-d]$",
            message = "Correct answer must be A, B, C or D"
    )
    private String correct;

    public LessonQuizBankRequest() {}

    public String getText() {
        return text;
    }

    public void setText(
            String text
    ) {
        this.text = text;
    }

    public List<String> getOptions() {
        return options;
    }

    public void setOptions(
            List<String> options
    ) {
        this.options = options;
    }

    public String getCorrect() {
        return correct;
    }

    public void setCorrect(
            String correct
    ) {
        this.correct =
                correct == null
                        ? null
                        : correct
                            .trim()
                            .toUpperCase();
    }
}