package com.learnova.instructor.dto;

import java.time.OffsetDateTime;

public interface InstructorRequestView {
    Long getId();
    Long getUserId();
    String getNote();
    String getStatus();
    OffsetDateTime getRequestedAt();
    String getFirstName();
    String getLastName();
    String getEmail();
}