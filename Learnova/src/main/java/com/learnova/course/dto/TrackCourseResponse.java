package com.learnova.course.dto;

public record TrackCourseResponse(
        Long courseId,
        String title,
        String description,
        int sequenceOrder
) {
}
