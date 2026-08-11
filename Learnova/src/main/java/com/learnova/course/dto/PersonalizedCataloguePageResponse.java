package com.learnova.course.dto;

import java.util.List;

public record PersonalizedCataloguePageResponse(
        List<PersonalizedCourseCardResponse> content,
        int page,
        int size,
        long totalElements,
        long totalPages,
        boolean first,
        boolean last
) {
    public PersonalizedCataloguePageResponse {
        content = List.copyOf(content);
    }
}
