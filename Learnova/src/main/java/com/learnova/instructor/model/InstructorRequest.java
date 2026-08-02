package com.learnova.instructor.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Entity
@Table(name = "instructor_requests")
public class InstructorRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, length = 20)
    private String status = "PENDING";

    @Column(name = "request_message")
    private String requestMessage;

    @Column(name = "reviewed_by")
    private Long reviewedBy;

    @Column(name = "reviewed_at")
    private OffsetDateTime reviewedAt;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public InstructorRequest() {
    }

    public InstructorRequest(Long userId, String requestMessage) {
        this.userId = userId;
        this.requestMessage = requestMessage;
        this.status = "PENDING";
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now(ZoneOffset.UTC);
        }
    }

    public void approve(Long adminId) {
        this.status = "APPROVED";
        this.reviewedBy = adminId;
        this.reviewedAt = OffsetDateTime.now(ZoneOffset.UTC);
        this.rejectionReason = null;
    }

    public void reject(Long adminId, String reason) {
        this.status = "REJECTED";
        this.reviewedBy = adminId;
        this.reviewedAt = OffsetDateTime.now(ZoneOffset.UTC);
        this.rejectionReason = reason == null || reason.isBlank()
                ? "Rejected by admin."
                : reason;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public String getStatus() {
        return status;
    }

    public String getRequestMessage() {
        return requestMessage;
    }

    public Long getReviewedBy() {
        return reviewedBy;
    }

    public OffsetDateTime getReviewedAt() {
        return reviewedAt;
    }

    public String getRejectionReason() {
        return rejectionReason;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
