package com.learnova.prerequisite.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class PrerequisiteRepository {

    private static final String LOAD_EDITOR_SQL = """
            SELECT *
            FROM public.fn_prerequisite_editor(
                :actorId,
                :courseId
            )
            """;


    private static final String REPLACE_PREREQUISITES_SQL = """
            SELECT *
            FROM public.sp_replace_course_prerequisites(
                :actorId,
                :courseId,
                CAST(:prerequisites AS JSONB)
            )
            """;


    private final NamedParameterJdbcTemplate jdbcTemplate;


    public PrerequisiteRepository(
            NamedParameterJdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate =
                jdbcTemplate;
    }


    public PrerequisiteEditorRow findEditor(
            Long actorId,
            Long courseId
    ) {

        MapSqlParameterSource parameters =
                new MapSqlParameterSource()

                        .addValue(
                                "actorId",
                                actorId
                        )

                        .addValue(
                                "courseId",
                                courseId
                        );


        return firstRow(
                LOAD_EDITOR_SQL,
                parameters
        );
    }


    public PrerequisiteEditorRow replacePrerequisites(
            Long actorId,
            Long courseId,
            String prerequisitesJson
    ) {

        MapSqlParameterSource parameters =
                new MapSqlParameterSource()

                        .addValue(
                                "actorId",
                                actorId
                        )

                        .addValue(
                                "courseId",
                                courseId
                        )

                        .addValue(
                                "prerequisites",
                                prerequisitesJson
                        );


        return firstRow(
                REPLACE_PREREQUISITES_SQL,
                parameters
        );
    }


    private PrerequisiteEditorRow firstRow(
            String sql,
            MapSqlParameterSource parameters
    ) {

        List<PrerequisiteEditorRow> rows =
                jdbcTemplate.query(
                        sql,
                        parameters,
                        (
                                resultSet,
                                rowNumber
                        ) ->
                                new PrerequisiteEditorRow(

                                        resultSet.getLong(
                                                "target_course_id"
                                        ),

                                        resultSet.getString(
                                                "target_title"
                                        ),

                                        resultSet.getString(
                                                "target_slug"
                                        ),

                                        resultSet.getString(
                                                "target_status"
                                        ),

                                        resultSet.getBoolean(
                                                "editable"
                                        ),

                                        resultSet.getString(
                                                "prerequisites"
                                        ),

                                        resultSet.getString(
                                                "candidates"
                                        )
                                )
                );


        return rows.isEmpty()
                ? null
                : rows.get(0);
    }


    public record PrerequisiteEditorRow(
            Long targetCourseId,
            String targetTitle,
            String targetSlug,
            String targetStatus,
            boolean editable,
            String prerequisitesJson,
            String candidatesJson
    ) {
    }
}