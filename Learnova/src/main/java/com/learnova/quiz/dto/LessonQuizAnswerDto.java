package com.learnova.quiz.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;

public class LessonQuizAnswerDto {

    @NotNull(
            message = "Question id is required"
    )
    @Positive(
            message = "Question id must be positive"
    )
    private Long id;

    @NotBlank(
            message = "Selected answer is required"
    )
    @Pattern(
            regexp = "^[A-Da-d]$",
            message = "Selected answer must be A, B, C or D"
    )
    private String selected;

    public LessonQuizAnswerDto() {}

    public LessonQuizAnswerDto(
            Long id,
            String selected
    ) {
        this.id = id;
        setSelected(selected);
    }

    public Long getId() {
        return id;
    }

    public void setId(
            Long id
    ) {
        this.id = id;
    }

    public String getSelected() {
        return selected;
    }

    public void setSelected(
            String selected
    ) {
        this.selected =
                selected == null
                        ? null
                        : selected
                            .trim()
                            .toUpperCase();
    }
}