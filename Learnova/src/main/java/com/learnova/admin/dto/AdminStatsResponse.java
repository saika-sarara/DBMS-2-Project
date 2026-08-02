package com.learnova.admin.dto;

public class AdminStatsResponse {

    private long users;
    private long instructors;
    private long activeCourses;
    private long enrollments;

    public AdminStatsResponse(
            long users,
            long instructors,
            long activeCourses,
            long enrollments
    ) {
        this.users = users;
        this.instructors = instructors;
        this.activeCourses = activeCourses;
        this.enrollments = enrollments;
    }

    public long getUsers() {
        return users;
    }

    public long getInstructors() {
        return instructors;
    }

    public long getActiveCourses() {
        return activeCourses;
    }

    public long getEnrollments() {
        return enrollments;
    }
}
