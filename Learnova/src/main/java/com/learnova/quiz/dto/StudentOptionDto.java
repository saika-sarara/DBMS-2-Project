package com.learnova.quiz.dto;

public class StudentOptionDto {
    private Long optionId;
    private String displayLabel;
    private String optionText;

    public StudentOptionDto() {}

    public StudentOptionDto(Long optionId, String displayLabel, String optionText) {
        this.optionId = optionId;
        this.displayLabel = displayLabel;
        this.optionText = optionText;
    }

    public Long getOptionId() { return optionId; }
    public void setOptionId(Long optionId) { this.optionId = optionId; }
    public String getDisplayLabel() { return displayLabel; }
    public void setDisplayLabel(String displayLabel) { this.displayLabel = displayLabel; }
    public String getOptionText() { return optionText; }
    public void setOptionText(String optionText) { this.optionText = optionText; }
}
