package com.learnova.prerequisite.dto;

import java.math.BigDecimal;
import java.util.List;

public record PrerequisiteEditorResponse(
        Long targetCourseId,
        String targetTitle,
        String targetSlug,
        String targetStatus,
        boolean editable,
        List<Prerequisite> prerequisites,
        List<Candidate> candidates
) {

    public PrerequisiteEditorResponse {

        prerequisites =
                prerequisites == null
                        ? List.of()
                        : List.copyOf(prerequisites);

        candidates =
                candidates == null
                        ? List.of()
                        : List.copyOf(candidates);
    }


    public record Prerequisite(
            Long courseId,
            String title,
            String slug,
            String status,
            BigDecimal requiredMinScore
    ) {
    }


    public record Candidate(
            Long courseId,
            String title,
            String slug,
            String status
    ) {
    }
}