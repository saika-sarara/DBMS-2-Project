package com.learnova.course.repository;

import com.learnova.course.dto.CategoryResponse;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class CategoryRepository {

    private static final String FIND_ACTIVE_CATEGORIES_SQL = """
            SELECT
                id,
                name,
                description
            FROM public.categories
            WHERE is_active = TRUE
            ORDER BY name ASC
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CategoryRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<CategoryResponse> findActiveCategories() {
        return jdbcTemplate.query(
                FIND_ACTIVE_CATEGORIES_SQL,
                Map.of(),
                (resultSet, rowNumber) -> new CategoryResponse(
                        resultSet.getLong("id"),
                        resultSet.getString("name"),
                        resultSet.getString("description")
                )
        );
    }
}