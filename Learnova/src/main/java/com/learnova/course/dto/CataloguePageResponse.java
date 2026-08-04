package com.learnova.course.dto;

import java.util.List;

public record CataloguePageResponse(
        List<CourseCardResponse> content,
        int page,
        int size,
        long totalElements,
        long totalPages,
        boolean first,
        boolean last
) {
    public CataloguePageResponse {
        content = List.copyOf(content);
    }
}