package com.learnova.course.dto;

import java.util.List;

public record TrackResponse(
        Long id,
        String title,
        String description,
        String status,
        List<TrackCourseResponse> courses
) {
}