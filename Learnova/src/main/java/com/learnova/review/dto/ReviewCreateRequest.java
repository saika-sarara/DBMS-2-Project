
package com.learnova.review.dto;

public record ReviewCreateRequest(
        Integer rating,
        String comment
) {}