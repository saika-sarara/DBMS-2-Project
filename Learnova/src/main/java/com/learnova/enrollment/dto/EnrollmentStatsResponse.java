package com.learnova.enrollment.dto;

/**
 * Fresh platform-wide counters from fn_admin_enrollment_stats().
 */
public class EnrollmentStatsResponse {

    private Long totalUsers;
    private Long activeStudents;
    private Long totalCourses;
    private Long publishedCourses;
    private Long totalEnrollments;
    private Long activeEnrollments;
    private Long completedEnrollments;
    private Long distinctStudents;

    public Long getTotalUsers() {
        return totalUsers;
    }

    public void setTotalUsers(Long totalUsers) {
        this.totalUsers = totalUsers;
    }

    public Long getActiveStudents() {
        return activeStudents;
    }

    public void setActiveStudents(Long activeStudents) {
        this.activeStudents = activeStudents;
    }

    public Long getTotalCourses() {
        return totalCourses;
    }

    public void setTotalCourses(Long totalCourses) {
        this.totalCourses = totalCourses;
    }

    public Long getPublishedCourses() {
        return publishedCourses;
    }

    public void setPublishedCourses(Long publishedCourses) {
        this.publishedCourses = publishedCourses;
    }

    public Long getTotalEnrollments() {
        return totalEnrollments;
    }

    public void setTotalEnrollments(Long totalEnrollments) {
        this.totalEnrollments = totalEnrollments;
    }

    public Long getActiveEnrollments() {
        return activeEnrollments;
    }

    public void setActiveEnrollments(Long activeEnrollments) {
        this.activeEnrollments = activeEnrollments;
    }

    public Long getCompletedEnrollments() {
        return completedEnrollments;
    }

    public void setCompletedEnrollments(Long completedEnrollments) {
        this.completedEnrollments = completedEnrollments;
    }

    public Long getDistinctStudents() {
        return distinctStudents;
    }

    public void setDistinctStudents(Long distinctStudents) {
        this.distinctStudents = distinctStudents;
    }
}
