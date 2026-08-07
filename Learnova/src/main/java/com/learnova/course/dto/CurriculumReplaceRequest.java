package com.learnova.course.dto;

import java.util.List;

public record CurriculumReplaceRequest(
        List<CurriculumModule> modules
) {
    public CurriculumReplaceRequest {
        modules = modules == null ? List.of() : List.copyOf(modules);
    }

    public record CurriculumModule(
            String title,
            String description,
            List<CurriculumLesson> lessons
    ) {
        public CurriculumModule {
            lessons = lessons == null ? List.of() : List.copyOf(lessons);
        }
    }

    public record CurriculumLesson(
            String title,
            Integer estimatedDurationMinutes,
            Boolean isPreview
    ) {
    }
}
