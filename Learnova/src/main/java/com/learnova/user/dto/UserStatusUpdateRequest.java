package com.learnova.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public class UserStatusUpdateRequest {

    @NotBlank(message = "status must not be blank")
    @Pattern(
            regexp = "(?i)active|suspended|banned|disabled",
            message = "status must be active, suspended, banned, or disabled"
    )
    private String status;

    public UserStatusUpdateRequest() {
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
