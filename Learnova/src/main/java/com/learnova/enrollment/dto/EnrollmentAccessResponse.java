package com.learnova.enrollment.dto;

import java.math.BigDecimal;

public class EnrollmentAccessResponse {

    private Long courseId;
    private Boolean accessible;
    private String reasonCode;
    private String reason;
    private String enrollmentStatus;
    private BigDecimal progressPct;
    private Long blockingCourseId;
    private String blockingCourseTitle;

    public static EnrollmentAccessResponse from(DatabaseAccessResult result, Long courseId) {
        EnrollmentAccessResponse response = new EnrollmentAccessResponse();
        response.setCourseId(courseId);
        response.setAccessible(result.getAccessible());
        response.setReasonCode(result.getReasonCode());
        response.setReason(result.getReason());
        response.setEnrollmentStatus(result.getEnrollmentStatus());
        response.setProgressPct(result.getProgressPct());
        response.setBlockingCourseId(result.getBlockingCourseId());
        response.setBlockingCourseTitle(result.getBlockingCourseTitle());
        return response;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

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
