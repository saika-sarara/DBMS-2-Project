package com.learnova.course.repository;

import com.learnova.course.dto.ContentBlockResponse;
import com.learnova.course.dto.LessonResponse;
import com.learnova.course.dto.ModuleResponse;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class CourseContentRepository {

    private static final String CREATE_MODULE_SQL = """
            SELECT *
            FROM public.sp_create_module(
                :actorId,
                :courseId,
                :title,
                :description,
                :sequenceOrder
            )
            """;

    private static final String UPDATE_MODULE_SQL = """
            SELECT *
            FROM public.sp_update_module(
                :actorId,
                :moduleId,
                :title,
                :description,
                :sequenceOrder
            )
            """;

    private static final String DELETE_MODULE_SQL = """
            SELECT *
            FROM public.sp_delete_module(:actorId, :moduleId)
            """;

    private static final String CREATE_LESSON_SQL = """
            SELECT *
            FROM public.sp_create_lesson(
                :actorId,
                :moduleId,
                :title,
                :description,
                :sequenceOrder,
                :estimatedDurationMinutes,
                :isPreview
            )
            """;

    private static final String UPDATE_LESSON_SQL = """
            SELECT *
            FROM public.sp_update_lesson(
                :actorId,
                :lessonId,
                :title,
                :description,
                :sequenceOrder,
                :estimatedDurationMinutes,
                :isPreview
            )
            """;

    private static final String DELETE_LESSON_SQL = """
            SELECT *
            FROM public.sp_delete_lesson(:actorId, :lessonId)
            """;

    private static final String CREATE_BLOCK_SQL = """
            SELECT *
            FROM public.sp_create_lesson_content_block(
                :actorId,
                :lessonId,
                :blockType,
                :title,
                :bodyMarkdown,
                :resourceUrl,
                :sequenceOrder
            )
            """;

    private static final String UPDATE_BLOCK_SQL = """
            SELECT *
            FROM public.sp_update_lesson_content_block(
                :actorId,
                :blockId,
                :title,
                :bodyMarkdown,
                :resourceUrl,
                :sequenceOrder
            )
            """;

    private static final String DELETE_BLOCK_SQL = """
            SELECT *
            FROM public.sp_delete_lesson_content_block(:actorId, :blockId)
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CourseContentRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public ModuleResponse createModule(
            Long actorId,
            Long courseId,
            String title,
            String description,
            Integer sequenceOrder
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId)
                .addValue("title", title)
                .addValue("description", description)
                .addValue("sequenceOrder", sequenceOrder);

        return firstRow(CREATE_MODULE_SQL, parameters, moduleMapper());
    }

    public ModuleResponse updateModule(
            Long actorId,
            Long moduleId,
            String title,
            String description,
            Integer sequenceOrder
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("moduleId", moduleId)
                .addValue("title", title)
                .addValue("description", description)
                .addValue("sequenceOrder", sequenceOrder);

        return firstRow(UPDATE_MODULE_SQL, parameters, moduleMapper());
    }

    public Long deleteModule(Long actorId, Long moduleId) {
        return firstRow(
                DELETE_MODULE_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("moduleId", moduleId),
                (resultSet, rowNumber) ->
                        resultSet.getLong("module_id")
        );
    }

    public LessonResponse createLesson(
            Long actorId,
            Long moduleId,
            String title,
            String description,
            Integer sequenceOrder,
            Integer estimatedDurationMinutes,
            Boolean isPreview
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("moduleId", moduleId)
                .addValue("title", title)
                .addValue("description", description)
                .addValue("sequenceOrder", sequenceOrder)
                .addValue("estimatedDurationMinutes", estimatedDurationMinutes)
                .addValue("isPreview", isPreview);

        return firstRow(CREATE_LESSON_SQL, parameters, lessonMapper());
    }

    public LessonResponse updateLesson(
            Long actorId,
            Long lessonId,
            String title,
            String description,
            Integer sequenceOrder,
            Integer estimatedDurationMinutes,
            Boolean isPreview
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("lessonId", lessonId)
                .addValue("title", title)
                .addValue("description", description)
                .addValue("sequenceOrder", sequenceOrder)
                .addValue("estimatedDurationMinutes", estimatedDurationMinutes)
                .addValue("isPreview", isPreview);

        return firstRow(UPDATE_LESSON_SQL, parameters, lessonMapper());
    }

    public Long deleteLesson(Long actorId, Long lessonId) {
        return firstRow(
                DELETE_LESSON_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("lessonId", lessonId),
                (resultSet, rowNumber) ->
                        resultSet.getLong("lesson_id")
        );
    }

    public ContentBlockResponse createBlock(
            Long actorId,
            Long lessonId,
            String blockType,
            String title,
            String bodyMarkdown,
            String resourceUrl,
            Integer sequenceOrder
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("lessonId", lessonId)
                .addValue("blockType", blockType)
                .addValue("title", title)
                .addValue("bodyMarkdown", bodyMarkdown)
                .addValue("resourceUrl", resourceUrl)
                .addValue("sequenceOrder", sequenceOrder);

        return firstRow(CREATE_BLOCK_SQL, parameters, blockMapper());
    }

    public ContentBlockResponse updateBlock(
            Long actorId,
            Long blockId,
            String title,
            String bodyMarkdown,
            String resourceUrl,
            Integer sequenceOrder
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("blockId", blockId)
                .addValue("title", title)
                .addValue("bodyMarkdown", bodyMarkdown)
                .addValue("resourceUrl", resourceUrl)
                .addValue("sequenceOrder", sequenceOrder);

        return firstRow(UPDATE_BLOCK_SQL, parameters, blockMapper());
    }

    public Long deleteBlock(Long actorId, Long blockId) {
        return firstRow(
                DELETE_BLOCK_SQL,
                new MapSqlParameterSource()
                        .addValue("actorId", actorId)
                        .addValue("blockId", blockId),
                (resultSet, rowNumber) ->
                        resultSet.getLong("block_id")
        );
    }

    private <T> T firstRow(
            String sql,
            MapSqlParameterSource parameters,
            RowMapper<T> mapper
    ) {
        List<T> rows = jdbcTemplate.query(sql, parameters, mapper);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private RowMapper<ModuleResponse> moduleMapper() {
        return (resultSet, rowNumber) -> new ModuleResponse(
                resultSet.getLong("module_id"),
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("description"),
                resultSet.getObject("sequence_order", Integer.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class)
        );
    }

    private RowMapper<LessonResponse> lessonMapper() {
        return (resultSet, rowNumber) -> new LessonResponse(
                resultSet.getLong("lesson_id"),
                resultSet.getObject("module_id", Long.class),
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("description"),
                resultSet.getObject("sequence_order", Integer.class),
                resultSet.getObject("estimated_duration_minutes", Integer.class),
                resultSet.getBoolean("is_preview"),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class)
        );
    }

    private RowMapper<ContentBlockResponse> blockMapper() {
        return (resultSet, rowNumber) -> new ContentBlockResponse(
                resultSet.getLong("block_id"),
                resultSet.getLong("lesson_id"),
                resultSet.getString("block_type"),
                resultSet.getString("title"),
                resultSet.getString("body_markdown"),
                resultSet.getString("resource_url"),
                resultSet.getObject("sequence_order", Integer.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class)
        );
    }
}
