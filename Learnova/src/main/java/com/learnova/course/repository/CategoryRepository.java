package com.learnova.course.repository;

import com.learnova.course.dto.AdminCategoryResponse;
import com.learnova.course.dto.CategoryResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
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

    private static final String FIND_ALL_CATEGORIES_SQL = """
            SELECT
                id,
                name,
                slug,
                description,
                is_active,
                created_at,
                updated_at
            FROM public.categories
            ORDER BY name ASC
            """;

    private static final String CREATE_CATEGORY_SQL = """
            SELECT *
            FROM public.sp_create_category(:actorId, :name, :description)
            """;

    private static final String UPDATE_CATEGORY_SQL = """
            SELECT *
            FROM public.sp_update_category(
                :actorId,
                :categoryId,
                :name,
                :description,
                :isActive
            )
            """;

    private static final String DELETE_CATEGORY_SQL = """
            SELECT *
            FROM public.sp_delete_category(:actorId, :categoryId)
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

    public List<AdminCategoryResponse> findAllCategories() {
        return jdbcTemplate.query(
                FIND_ALL_CATEGORIES_SQL,
                Map.of(),
                (resultSet, rowNumber) -> new AdminCategoryResponse(
                        resultSet.getLong("id"),
                        resultSet.getString("name"),
                        resultSet.getString("slug"),
                        resultSet.getString("description"),
                        resultSet.getBoolean("is_active"),
                        resultSet.getObject("created_at", OffsetDateTime.class),
                        resultSet.getObject("updated_at", OffsetDateTime.class)
                )
        );
    }

    public AdminCategoryResponse createCategory(
            Long actorId,
            String name,
            String description
    ) {
        return firstRow(
                CREATE_CATEGORY_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("name", name)
                        .addValue("description", description)
        );
    }

    public AdminCategoryResponse updateCategory(
            Long actorId,
            Long categoryId,
            String name,
            String description,
            Boolean isActive
    ) {
        return firstRow(
                UPDATE_CATEGORY_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("categoryId", categoryId)
                        .addValue("name", name)
                        .addValue("description", description)
                        .addValue("isActive", isActive)
        );
    }

    public Long deleteCategory(Long actorId, Long categoryId) {
        List<Long> rows = jdbcTemplate.query(
                DELETE_CATEGORY_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("categoryId", categoryId),
                (resultSet, rowNumber) ->
                        resultSet.getLong("category_id")
        );

        return rows.isEmpty() ? null : rows.get(0);
    }

    private AdminCategoryResponse firstRow(
            String sql,
            MapSqlParameterSource parameters
    ) {
        List<AdminCategoryResponse> rows = jdbcTemplate.query(
                sql,
                parameters,
                (resultSet, rowNumber) -> new AdminCategoryResponse(
                        resultSet.getLong("category_id"),
                        resultSet.getString("name"),
                        resultSet.getString("slug"),
                        resultSet.getString("description"),
                        resultSet.getBoolean("is_active"),
                        resultSet.getObject("created_at", OffsetDateTime.class),
                        resultSet.getObject("updated_at", OffsetDateTime.class)
                )
        );

        return rows.isEmpty() ? null : rows.get(0);
    }
}