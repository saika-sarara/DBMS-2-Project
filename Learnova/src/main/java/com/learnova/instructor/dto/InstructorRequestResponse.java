package com.learnova.instructor.dto;

import com.learnova.instructor.model.InstructorRequest;
import com.learnova.user.model.User;

import java.time.OffsetDateTime;
import java.util.Locale;

public class InstructorRequestResponse {

    private Long id;
    private Long userId;
    private String name;
    private String email;
    private String note;
    private String status;
    private OffsetDateTime requestedAt;
    private OffsetDateTime created_at;

    public static InstructorRequestResponse from(
            InstructorRequest request,
            User user
    ) {
        InstructorRequestResponse response = new InstructorRequestResponse();
        response.id = request.getId();
        response.userId = request.getUserId();
        response.name = user.getFullName();
        response.email = user.getEmail();
        response.note = request.getRequestMessage();
        response.status = request.getStatus() == null
                ? "pending"
                : request.getStatus().toLowerCase(Locale.ROOT);
        response.requestedAt = request.getCreatedAt();
        response.created_at = request.getCreatedAt();
        return response;
    }

    public static InstructorRequestResponse fromView(
            InstructorRequestView view
    ) {
        InstructorRequestResponse response = new InstructorRequestResponse();
        response.id = view.getId();
        response.userId = view.getUserId();
        response.name = (view.getFirstName() + " " + view.getLastName()).trim();
        response.email = view.getEmail();
        response.note = view.getNote();
        response.status = view.getStatus() == null
                ? "pending"
                : view.getStatus().toLowerCase(Locale.ROOT);
        response.requestedAt = view.getRequestedAt();
        response.created_at = view.getRequestedAt();
        return response;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public String getNote() {
        return note;
    }

    public String getStatus() {
        return status;
    }

    public OffsetDateTime getRequestedAt() {
        return requestedAt;
    }

    public OffsetDateTime getCreated_at() {
        return created_at;
    }
}
