package com.learnova.authentication.dto;

import java.util.LinkedHashSet;
import java.util.Set;

public class LoginResponse {

    private Long id;
    private String token;
    private String email;
    private String name;
    private String fullName;
    private Set<String> roles;
    private String role;
    private String primaryRole;
    private String status;

    public LoginResponse(
            Long id,
            String token,
            String email,
            String fullName,
            Set<String> roles,
            String status
    ) {
        this.id = id;
        this.token = token;
        this.email = email;
        this.name = fullName;
        this.fullName = fullName;
        this.roles = roles == null ? new LinkedHashSet<>() : roles;
        this.role = pickPrimaryRole(this.roles);
        this.primaryRole = this.role;
        this.status = status;
    }

    private String pickPrimaryRole(Set<String> roles) {
        if (roles.contains("Admin")) {
            return "Admin";
        }
        if (roles.contains("Instructor")) {
            return "Instructor";
        }
        if (roles.contains("Student")) {
            return "Student";
        }
        return roles.isEmpty() ? null : roles.iterator().next();
    }

    public Long getId() {
        return id;
    }

    public String getToken() {
        return token;
    }

    public String getEmail() {
        return email;
    }

    public String getName() {
        return name;
    }

    public String getFullName() {
        return fullName;
    }

    public Set<String> getRoles() {
        return roles;
    }

    public String getRole() {
        return role;
    }

    public String getPrimaryRole() {
        return primaryRole;
    }

    public String getStatus() {
        return status;
    }
}