package com.learnova.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public class RoleAssignmentRequest {

    @NotBlank(message = "role must not be blank")
    @Pattern(
            regexp = "(?i)ADMIN|INSTRUCTOR|STUDENT",
            message = "role must be ADMIN, INSTRUCTOR, or STUDENT"
    )
    private String role;

    public RoleAssignmentRequest() {
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }
}
