package com.learnova.enrollment.dto;

public class EnrollmentRequest {

    private Long courseId;
    private Long trackId;
    private String source;

    public EnrollmentRequest() {}

    public EnrollmentRequest(Long courseId, Long trackId, String source) {
        this.courseId = courseId;
        this.trackId = trackId;
        this.source = source;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Long getTrackId() {
        return trackId;
    }

    public void setTrackId(Long trackId) {
        this.trackId = trackId;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }
}
