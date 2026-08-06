package com.learnova.course.dto;

import java.util.List;

public record CourseSyllabusResponse(
        List<SyllabusModule> modules
) {
    public CourseSyllabusResponse {
        modules = List.copyOf(modules);
    }

    public record SyllabusModule(
            Long moduleId,
            String title,
            Integer sequenceOrder,
            List<SyllabusLesson> lessons
    ) {
        public SyllabusModule {
            lessons = List.copyOf(lessons);
        }
    }

    public record SyllabusLesson(
            Long lessonId,
            String title,
            Integer sequenceOrder,
            Integer estimatedDurationMinutes,
            boolean preview,
            String accessStatus
    ) {
    }
}
