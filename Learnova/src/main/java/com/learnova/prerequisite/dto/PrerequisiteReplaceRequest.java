package com.learnova.prerequisite.dto;

import java.math.BigDecimal;
import java.util.List;

public record PrerequisiteReplaceRequest(
        List<Item> prerequisites
) {

    public PrerequisiteReplaceRequest {

        prerequisites =
                prerequisites == null
                        ? List.of()
                        : List.copyOf(prerequisites);
    }


    public record Item(
            Long prerequisiteCourseId,
            BigDecimal requiredMinScore
    ) {
    }
}