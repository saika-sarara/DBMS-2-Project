package com.learnova.admin.dto;

public record RoleMetadataResponse(
        String name,
        String description,
        long userCount
) {
}
