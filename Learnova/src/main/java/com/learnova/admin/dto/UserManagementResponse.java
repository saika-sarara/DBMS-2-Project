package com.learnova.admin.dto;

import com.learnova.user.model.Role;
import com.learnova.user.model.User;

import java.time.OffsetDateTime;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

public class UserManagementResponse {

    private Long id;
    private String name;
    private String email;
    private Set<String> roles;
    private String role;
    private String status;
    private OffsetDateTime joined;

    public UserManagementResponse() {
    }

    public static UserManagementResponse from(User user) {
        Set<String> roles = user.getRoles()
                .stream()
                .map(Role::getName)
                .map(UserManagementResponse::toFrontendRole)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        UserManagementResponse response = new UserManagementResponse();
        response.setId(user.getId());
        response.setName(user.getFullName());
        response.setEmail(user.getEmail());
        response.setRoles(roles);
        response.setRole(pickPrimaryRole(roles));
        response.setStatus(toFrontendStatus(user.getAccountStatus()));
        response.setJoined(user.getCreatedAt());
        return response;
    }

    private static String toFrontendRole(String role) {
        if ("ADMIN".equalsIgnoreCase(role)) {
            return "Admin";
        }
        if ("INSTRUCTOR".equalsIgnoreCase(role)) {
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

    private static String toFrontendStatus(String status) {
        if (status == null) {
            return "active";
        }
        String value = status.toUpperCase(Locale.ROOT);
        if ("SUSPENDED".equals(value)) {
            return "suspended";
        }
        if ("BANNED".equals(value) || "DISABLED".equals(value)) {
            return "banned";
        }
        return "active";
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public Set<String> getRoles() {
        return roles;
    }

    public String getRole() {
        return role;
    }

    public String getStatus() {
        return status;
    }

    public OffsetDateTime getJoined() {
        return joined;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public void setRoles(Set<String> roles) {
        this.roles = roles;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public void setJoined(OffsetDateTime joined) {
        this.joined = joined;
    }
}
