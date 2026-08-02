package com.learnova.user.dto;

import com.learnova.user.model.Role;
import com.learnova.user.model.User;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

public class UserProfileResponse {

    private Long id;
    private String email;
    private String fullName;
    private Set<String> roles;
    private String role;
    private String status;

    public UserProfileResponse() {
    }

    public static UserProfileResponse from(User user) {
        Set<String> frontendRoles = user.getRoles()
                .stream()
                .map(Role::getName)
                .map(UserProfileResponse::toFrontendRole)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        UserProfileResponse response = new UserProfileResponse();
        response.setId(user.getId());
        response.setEmail(user.getEmail());
        response.setFullName(user.getFullName());
        response.setRoles(frontendRoles);
        response.setRole(pickPrimaryRole(frontendRoles));
        response.setStatus(user.getAccountStatus() == null
                ? "ACTIVE"
                : user.getAccountStatus().toLowerCase(Locale.ROOT));
        return response;
    }

    private static String toFrontendRole(String databaseRole) {
        if ("ADMIN".equalsIgnoreCase(databaseRole)) {
            return "Admin";
        }
        if ("INSTRUCTOR".equalsIgnoreCase(databaseRole)) {
            return "Instructor";
        }
        return "Student";
    }

    private static String pickPrimaryRole(Set<String> roles) {
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

    public void setId(Long id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getFullName() {
        return fullName;
    }

    public void setFullName(String fullName) {
        this.fullName = fullName;
    }

    public Set<String> getRoles() {
        return roles;
    }

    public void setRoles(Set<String> roles) {
        this.roles = roles;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
