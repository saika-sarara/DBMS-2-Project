package com.learnova.course.dto;

import java.time.OffsetDateTime;

public record CourseLifecycleResponse(
        Long courseId,
        String title,
        String slug,
        String status,
        OffsetDateTime submittedAt,
        OffsetDateTime publishedAt,
        String rejectionReason,
        Long publishedBy
) {
}
