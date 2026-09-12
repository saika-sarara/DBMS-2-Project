package com.learnova.course.dto;

public record TrackUpdateRequest(
        String title,
        String description,
        String status
) {
}