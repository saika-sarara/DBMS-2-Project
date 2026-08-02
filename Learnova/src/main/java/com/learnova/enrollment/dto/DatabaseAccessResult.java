package com.learnova.enrollment.dto;

import java.math.BigDecimal;

public class DatabaseAccessResult {

    private Boolean accessible;
    private String reasonCode;
    private String reason;
    private String enrollmentStatus;
    private BigDecimal progressPct;
    private Long blockingCourseId;
    private String blockingCourseTitle;

    public Boolean getAccessible() {
        return accessible;
    }

    public void setAccessible(Boolean accessible) {
        this.accessible = accessible;
    }

    public String getReasonCode() {
        return reasonCode;
    }

    public void setReasonCode(String reasonCode) {
        this.reasonCode = reasonCode;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public String getEnrollmentStatus() {
        return enrollmentStatus;
    }

    public void setEnrollmentStatus(String enrollmentStatus) {
        this.enrollmentStatus = enrollmentStatus;
    }

    public BigDecimal getProgressPct() {
        return progressPct;
    }

    public void setProgressPct(BigDecimal progressPct) {
        this.progressPct = progressPct;
    }

    public Long getBlockingCourseId() {
        return blockingCourseId;
    }

    public void setBlockingCourseId(Long blockingCourseId) {
        this.blockingCourseId = blockingCourseId;
    }

    public String getBlockingCourseTitle() {
        return blockingCourseTitle;
    }

    public void setBlockingCourseTitle(String blockingCourseTitle) {
        this.blockingCourseTitle = blockingCourseTitle;
    }
}
