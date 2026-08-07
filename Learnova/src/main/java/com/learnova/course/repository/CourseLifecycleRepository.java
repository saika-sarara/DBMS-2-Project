package com.learnova.course.repository;

import com.learnova.course.dto.AdminCourseResponse;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.InstructorCourseResponse;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;

@Repository
public class CourseLifecycleRepository {

    private static final String INSTRUCTOR_COURSES_SQL = """
            SELECT *
            FROM public.fn_instructor_courses(:instructorId)
            """;

    private static final String ADMIN_COURSES_SQL = """
            SELECT *
            FROM public.fn_admin_courses(:statusFilter)
            """;

    private static final String CREATE_DRAFT_SQL = """
            SELECT *
            FROM public.sp_create_course_draft(
                :actorId,
                :categoryId,
                :title,
                :shortDescription,
                :description,
                :difficulty,
                :thumbnailUrl
            )
            """;

    private static final String UPDATE_BASIC_INFO_SQL = """
            SELECT *
            FROM public.sp_update_course_basic_info(
                :actorId,
                :courseId,
                :categoryId,
                :title,
                :shortDescription,
                :description,
                :difficulty,
                :thumbnailUrl
            )
            """;

    private static final String SUBMIT_FOR_REVIEW_SQL = """
            SELECT *
            FROM public.sp_submit_course_for_review(:actorId, :courseId)
            """;

    private static final String DELETE_COURSE_SQL = """
            SELECT *
            FROM public.sp_delete_course(:actorId, :courseId)
            """;

    private static final String PUBLISH_COURSE_SQL = """
            SELECT *
            FROM public.sp_publish_course(:actorId, :courseId)
            """;

    private static final String REJECT_COURSE_SQL = """
            SELECT *
            FROM public.sp_reject_course(:actorId, :courseId, :reason)
            """;

    private static final String ARCHIVE_COURSE_SQL = """
            SELECT *
            FROM public.sp_archive_course(:actorId, :courseId)
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CourseLifecycleRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<InstructorCourseResponse> findInstructorCourses(Long instructorId) {
        return jdbcTemplate.query(
                INSTRUCTOR_COURSES_SQL,
                new MapSqlParameterSource("instructorId", instructorId),
                instructorCourseMapper()
        );
    }

    public List<AdminCourseResponse> findAdminCourses(String statusFilter) {
        return jdbcTemplate.query(
                ADMIN_COURSES_SQL,
                new MapSqlParameterSource("statusFilter", statusFilter),
                adminCourseMapper()
        );
    }

    public CourseLifecycleResponse createDraft(
            Long actorId,
            Long categoryId,
            String title,
            String shortDescription,
            String description,
            String difficulty,
            String thumbnailUrl
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("categoryId", categoryId)
                .addValue("title", title)
                .addValue("shortDescription", shortDescription)
                .addValue("description", description)
                .addValue("difficulty", difficulty)
                .addValue("thumbnailUrl", thumbnailUrl);

        return firstRow(CREATE_DRAFT_SQL, parameters, draftMapper());
    }

    public CourseLifecycleResponse updateBasicInfo(
            Long actorId,
            Long courseId,
            Long categoryId,
            String title,
            String shortDescription,
            String description,
            String difficulty,
            String thumbnailUrl
    ) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId)
                .addValue("categoryId", categoryId)
                .addValue("title", title)
                .addValue("shortDescription", shortDescription)
                .addValue("description", description)
                .addValue("difficulty", difficulty)
                .addValue("thumbnailUrl", thumbnailUrl);

        return firstRow(UPDATE_BASIC_INFO_SQL, parameters, draftMapper());
    }

    public CourseLifecycleResponse submitForReview(Long actorId, Long courseId) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId);

        return firstRow(SUBMIT_FOR_REVIEW_SQL, parameters, submitMapper());
    }

    public CourseLifecycleResponse publish(Long actorId, Long courseId) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId);

        return firstRow(PUBLISH_COURSE_SQL, parameters, publishMapper());
    }

    public CourseLifecycleResponse reject(Long actorId, Long courseId, String reason) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId)
                .addValue("reason", reason);

        return firstRow(REJECT_COURSE_SQL, parameters, moderationMapper());
    }

    public CourseLifecycleResponse archive(Long actorId, Long courseId) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId);

        return firstRow(ARCHIVE_COURSE_SQL, parameters, statusOnlyMapper());
    }

    public CourseLifecycleResponse deleteCourse(Long actorId, Long courseId) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("courseId", courseId);

        return firstRow(DELETE_COURSE_SQL, parameters, statusOnlyMapper());
    }

    private CourseLifecycleResponse firstRow(
            String sql,
            MapSqlParameterSource parameters,
            RowMapper<CourseLifecycleResponse> mapper
    ) {
        List<CourseLifecycleResponse> rows = jdbcTemplate.query(
                sql,
                parameters,
                mapper
        );

        return rows.isEmpty() ? null : rows.get(0);
    }

    /*
     * sp_create_course_draft and sp_update_course_basic_info return the
     * full editable course shape but no moderation timestamps.
     */
    private RowMapper<CourseLifecycleResponse> draftMapper() {
        return (resultSet, rowNumber) -> new CourseLifecycleResponse(
                resultSet.getObject("course_id", Long.class),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                null,
                null,
                null,
                null
        );
    }

    /*
     * sp_submit_course_for_review returns submitted_at + rejection_reason.
     */
    private RowMapper<CourseLifecycleResponse> submitMapper() {
        return (resultSet, rowNumber) -> new CourseLifecycleResponse(
                resultSet.getObject("course_id", Long.class),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                resultSet.getObject("submitted_at", OffsetDateTime.class),
                null,
                resultSet.getString("rejection_reason"),
                null
        );
    }

    /*
     * sp_publish_course returns published_by + published_at.
     */
    private RowMapper<CourseLifecycleResponse> publishMapper() {
        return (resultSet, rowNumber) -> new CourseLifecycleResponse(
                resultSet.getObject("course_id", Long.class),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                null,
                resultSet.getObject("published_at", OffsetDateTime.class),
                null,
                resultSet.getObject("published_by", Long.class)
        );
    }

    /*
     * sp_reject_course returns rejection_reason only.
     */
    private RowMapper<CourseLifecycleResponse> moderationMapper() {
        return (resultSet, rowNumber) -> new CourseLifecycleResponse(
                resultSet.getObject("course_id", Long.class),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                null,
                null,
                resultSet.getString("rejection_reason"),
                null
        );
    }

    /*
     * sp_archive_course returns only the id + slug + status.
     */
    private RowMapper<CourseLifecycleResponse> statusOnlyMapper() {
        return (resultSet, rowNumber) -> new CourseLifecycleResponse(
                resultSet.getObject("course_id", Long.class),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                null,
                null,
                null,
                null
        );
    }

    private RowMapper<InstructorCourseResponse> instructorCourseMapper() {
        return (resultSet, rowNumber) -> new InstructorCourseResponse(
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                lowerDifficulty(resultSet.getString("difficulty")),
                nullableLong(resultSet, "category_id"),
                resultSet.getString("category_name"),
                nullableLong(resultSet, "instructor_id"),
                resultSet.getString("instructor_name"),
                resultSet.getString("short_description"),
                resultSet.getString("description"),
                resultSet.getString("thumbnail_url"),
                resultSet.getLong("module_count"),
                resultSet.getLong("lesson_count"),
                resultSet.getString("rejection_reason"),
                resultSet.getObject("submitted_at", OffsetDateTime.class),
                resultSet.getObject("published_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class)
        );
    }

    private RowMapper<AdminCourseResponse> adminCourseMapper() {
        return (resultSet, rowNumber) -> new AdminCourseResponse(
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                lowerStatus(resultSet.getString("status")),
                lowerDifficulty(resultSet.getString("difficulty")),
                nullableLong(resultSet, "category_id"),
                resultSet.getString("category_name"),
                nullableLong(resultSet, "instructor_id"),
                resultSet.getString("instructor_name"),
                resultSet.getString("short_description"),
                resultSet.getString("description"),
                resultSet.getString("thumbnail_url"),
                resultSet.getLong("module_count"),
                resultSet.getLong("lesson_count"),
                resultSet.getString("rejection_reason"),
                resultSet.getObject("submitted_at", OffsetDateTime.class),
                resultSet.getObject("published_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class)
        );
    }

    private Long nullableLong(java.sql.ResultSet resultSet, String column)
            throws java.sql.SQLException {
        Object value = resultSet.getObject(column);
        return value == null ? null : resultSet.getLong(column);
    }

    private String lowerDifficulty(String difficulty) {
        return difficulty == null
                ? null
                : difficulty.toLowerCase(Locale.ROOT);
    }

    private String lowerStatus(String status) {
        return status == null
                ? null
                : status.toLowerCase(Locale.ROOT);
    }
}
