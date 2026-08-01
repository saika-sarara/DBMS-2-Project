package com.learnova.authentication.dto;

import java.util.Set;

public class LoginResponse {
    private String token;
    private String email;
    private String fullName;
    private Set<String> roles;

    public LoginResponse(String token, String email, String fullName, Set<String> roles) {
        this.token = token;
        this.email = email;
        this.fullName = fullName;
        this.roles = roles;
    }

    public String getToken() { return token; }
    public String getEmail() { return email; }
    public String getFullName() { return fullName; }
    public Set<String> getRoles() { return roles; }
}