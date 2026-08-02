package com.learnova.enrollment.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public class DatabaseEnrollmentResult {

    private Long enrollmentId;
    private Long entityId;
    private String entityTitle;
    private String status;
    private BigDecimal progressPct;
    private String source;
    private OffsetDateTime enrolledAt;
    private boolean alreadyEnrolled;

    public Long getEnrollmentId() {
        return enrollmentId;
    }

    public void setEnrollmentId(Long enrollmentId) {
        this.enrollmentId = enrollmentId;
    }

    public Long getEntityId() {
        return entityId;
    }

    public void setEntityId(Long entityId) {
        this.entityId = entityId;
    }

    public String getEntityTitle() {
        return entityTitle;
    }

    public void setEntityTitle(String entityTitle) {
        this.entityTitle = entityTitle;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public BigDecimal getProgressPct() {
        return progressPct;
    }

    public void setProgressPct(BigDecimal progressPct) {
        this.progressPct = progressPct;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public OffsetDateTime getEnrolledAt() {
        return enrolledAt;
    }

    public void setEnrolledAt(OffsetDateTime enrolledAt) {
        this.enrolledAt = enrolledAt;
    }

    public boolean isAlreadyEnrolled() {
        return alreadyEnrolled;
    }

    public void setAlreadyEnrolled(boolean alreadyEnrolled) {
        this.alreadyEnrolled = alreadyEnrolled;
    }
}
