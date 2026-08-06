package com.learnova.course.repository;

import com.learnova.course.dto.CourseDetailsResponse;
import com.learnova.course.dto.CourseSyllabusResponse;
import com.learnova.course.dto.LessonContentBlockResponse;
import com.learnova.course.dto.PersonalizedCourseCardResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Repository
public class CourseReadRepository {

    private static final String SEARCH_COURSES_SQL = """
            SELECT *
            FROM public.fn_search_course_catalogue(
                :studentId,
                :search,
                :categoryId,
                :difficulty,
                :sort,
                :limit,
                :offset
            )
            """;

    private static final String COURSE_DETAIL_SQL = """
            SELECT *
            FROM public.fn_course_detail(:studentId, :courseId)
            """;

    private static final String COURSE_SYLLABUS_SQL = """
            SELECT *
            FROM public.fn_course_syllabus(:studentId, :courseId)
            """;

    private static final String LESSON_CONTENT_SQL = """
            SELECT *
            FROM public.fn_course_content_for_lesson(:studentId, :lessonId)
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CourseReadRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public SearchResult search(
            Long studentId,
            String search,
            Long categoryId,
            String difficulty,
            String sort,
            int limit,
            int offset
    ) {
        MapSqlParameterSource parameters = createSearchParameters(
                studentId,
                search,
                categoryId,
                difficulty,
                sort,
                limit,
                offset
        );

        List<SearchRow> rows = jdbcTemplate.query(
                SEARCH_COURSES_SQL,
                parameters,
                (resultSet, rowNumber) -> new SearchRow(
                        mapPersonalizedCard(resultSet),
                        resultSet.getLong("total_count")
                )
        );

        if (rows.isEmpty()) {
            long totalElements = offset > 0
                    ? loadTotalCount(
                            studentId,
                            search,
                            categoryId,
                            difficulty,
                            sort
                    )
                    : 0L;

            return new SearchResult(List.of(), totalElements);
        }

        List<PersonalizedCourseCardResponse> courses = rows.stream()
                .map(SearchRow::course)
                .toList();

        return new SearchResult(courses, rows.get(0).totalCount());
    }

    public CourseDetailsResponse findCourseDetail(
            Long studentId,
            Long courseId
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("courseId", courseId);

        List<CourseDetailsResponse> results = jdbcTemplate.query(
                COURSE_DETAIL_SQL,
                parameters,
                (resultSet, rowNumber) -> mapDetails(resultSet)
        );

        return results.isEmpty() ? null : results.get(0);
    }

    public CourseSyllabusResponse findCourseSyllabus(
            Long studentId,
            Long courseId
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("courseId", courseId);

        List<SyllabusRow> rows = jdbcTemplate.query(
                COURSE_SYLLABUS_SQL,
                parameters,
                (resultSet, rowNumber) -> new SyllabusRow(
                        resultSet.getObject("module_id", Long.class),
                        resultSet.getString("module_title"),
                        resultSet.getObject("module_order", Integer.class),
                        new CourseSyllabusResponse.SyllabusLesson(
                                resultSet.getLong("lesson_id"),
                                resultSet.getString("lesson_title"),
                                resultSet.getObject("lesson_order", Integer.class),
                                resultSet.getObject("estimated_duration_minutes", Integer.class),
                                resultSet.getBoolean("is_preview"),
                                resultSet.getString("lesson_access_status")
                        )
                )
        );

        return buildSyllabus(rows);
    }

    public List<LessonContentBlockResponse> findLessonContent(
            Long studentId,
            Long lessonId
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("lessonId", lessonId);

        return jdbcTemplate.query(
                LESSON_CONTENT_SQL,
                parameters,
                (resultSet, rowNumber) -> new LessonContentBlockResponse(
                        resultSet.getLong("block_id"),
                        resultSet.getLong("lesson_id"),
                        resultSet.getString("block_type"),
                        resultSet.getString("title"),
                        resultSet.getString("body_markdown"),
                        resultSet.getString("resource_url"),
                        resultSet.getObject("sequence_order", Integer.class)
                )
        );
    }

    private CourseSyllabusResponse buildSyllabus(List<SyllabusRow> rows) {
        List<CourseSyllabusResponse.SyllabusModule> modules =
                new ArrayList<>();

        List<CourseSyllabusResponse.SyllabusLesson> orphanedLessons =
                new ArrayList<>();

        // Group lesson rows by module while preserving module order.
        Map<Integer, MutableModule> byOrder = new LinkedHashMap<>();

        for (SyllabusRow row : rows) {
            if (row.moduleId() == null) {
                orphanedLessons.add(row.lesson());
                continue;
            }

            MutableModule module = byOrder.computeIfAbsent(
                    row.moduleOrder(),
                    ignored -> new MutableModule(
                            row.moduleId(),
                            row.moduleTitle(),
                            row.moduleOrder()
                    )
            );

            List<CourseSyllabusResponse.SyllabusLesson> lessons =
                    module.lessons();

            if (lessons.isEmpty()
                    || !lessons.get(lessons.size() - 1).lessonId()
                            .equals(row.lesson().lessonId())) {
                lessons.add(row.lesson());
            }
        }

        byOrder.values().stream()
                .map(MutableModule::toResponse)
                .forEach(modules::add);

        // Legacy lessons (created before modules existed) have no module.
        // They are surfaced under a synthetic "Ungrouped" module.
        if (!orphanedLessons.isEmpty()) {
            modules.add(new CourseSyllabusResponse.SyllabusModule(
                    null,
                    "Ungrouped Lessons",
                    0,
                    orphanedLessons
            ));
        }

        return new CourseSyllabusResponse(modules);
    }

    private long loadTotalCount(
            Long studentId,
            String search,
            Long categoryId,
            String difficulty,
            String sort
    ) {
        MapSqlParameterSource parameters = createSearchParameters(
                studentId,
                search,
                categoryId,
                difficulty,
                sort,
                1,
                0
        );

        List<Long> totals = jdbcTemplate.query(
                SEARCH_COURSES_SQL,
                parameters,
                (resultSet, rowNumber) ->
                        resultSet.getLong("total_count")
        );

        return totals.isEmpty() ? 0L : totals.get(0);
    }

    private MapSqlParameterSource createSearchParameters(
            Long studentId,
            String search,
            Long categoryId,
            String difficulty,
            String sort,
            int limit,
            int offset
    ) {
        return new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("search", search)
                .addValue("categoryId", categoryId)
                .addValue("difficulty", difficulty)
                .addValue("sort", sort)
                .addValue("limit", limit)
                .addValue("offset", offset);
    }

    private PersonalizedCourseCardResponse mapPersonalizedCard(
            ResultSet resultSet
    ) throws SQLException {
        return new PersonalizedCourseCardResponse(
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                resultSet.getString("short_description"),
                resultSet.getString("thumbnail_url"),
                lowerDifficulty(resultSet.getString("difficulty")),
                nullableLong(resultSet, "category_id"),
                resultSet.getString("category_name"),
                resultSet.getBigDecimal("avg_rating"),
                resultSet.getInt("review_count"),
                resultSet.getInt("total_lessons"),
                resultSet.getInt("estimated_duration_minutes"),
                nullableLong(resultSet, "instructor_id"),
                resultSet.getString("instructor_name"),
                resultSet.getString("card_status"),
                resultSet.getBoolean("is_locked"),
                resultSet.getBoolean("is_enrolled"),
                resultSet.getBoolean("is_completed"),
                resultSet.getString("lock_reason"),
                resultSet.getDouble("rank_score")
        );
    }

    private CourseDetailsResponse mapDetails(
            ResultSet resultSet
    ) throws SQLException {
        List<String> tags = new ArrayList<>();

        java.sql.Array tagArray = resultSet.getArray("tags");

        if (tagArray != null) {
            Object[] values = (Object[]) tagArray.getArray();

            for (Object value : values) {
                tags.add(String.valueOf(value));
            }
        }

        return new CourseDetailsResponse(
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                resultSet.getString("short_description"),
                resultSet.getString("description"),
                lowerDifficulty(resultSet.getString("difficulty")),
                resultSet.getString("thumbnail_url"),
                nullableLong(resultSet, "category_id"),
                resultSet.getString("category_name"),
                nullableLong(resultSet, "instructor_id"),
                resultSet.getString("instructor_name"),
                resultSet.getBigDecimal("avg_rating"),
                resultSet.getInt("review_count"),
                resultSet.getInt("total_lessons"),
                resultSet.getInt("estimated_duration_minutes"),
                resultSet.getLong("total_modules"),
                resultSet.getObject("published_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getString("card_status"),
                resultSet.getBoolean("is_locked"),
                resultSet.getBoolean("is_enrolled"),
                resultSet.getBoolean("is_completed"),
                resultSet.getString("lock_reason"),
                tags
        );
    }

    private Long nullableLong(ResultSet resultSet, String column)
            throws SQLException {
        Object value = resultSet.getObject(column);
        return value == null ? null : resultSet.getLong(column);
    }

    private String lowerDifficulty(String difficulty) {
        return difficulty == null
                ? null
                : difficulty.toLowerCase(Locale.ROOT);
    }

    public record SearchResult(
            List<PersonalizedCourseCardResponse> content,
            long totalElements
    ) {
        public SearchResult {
            content = List.copyOf(content);
        }
    }

    private record SearchRow(
            PersonalizedCourseCardResponse course,
            long totalCount
    ) {
    }

    private record SyllabusRow(
            Long moduleId,
            String moduleTitle,
            Integer moduleOrder,
            CourseSyllabusResponse.SyllabusLesson lesson
    ) {
    }

    private static final class MutableModule {

        private final Long moduleId;
        private final String title;
        private final Integer sequenceOrder;
        private final List<CourseSyllabusResponse.SyllabusLesson> lessons =
                new ArrayList<>();

        private MutableModule(
                Long moduleId,
                String title,
                Integer sequenceOrder
        ) {
            this.moduleId = moduleId;
            this.title = title;
            this.sequenceOrder = sequenceOrder;
        }

        private List<CourseSyllabusResponse.SyllabusLesson> lessons() {
            return lessons;
        }

        private CourseSyllabusResponse.SyllabusModule toResponse() {
            return new CourseSyllabusResponse.SyllabusModule(
                    moduleId,
                    title,
                    sequenceOrder,
                    lessons
            );
        }
    }
}
