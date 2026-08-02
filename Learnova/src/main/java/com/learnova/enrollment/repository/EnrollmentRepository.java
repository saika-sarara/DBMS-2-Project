package com.learnova.enrollment.repository;

import com.learnova.enrollment.dto.DatabaseAccessResult;
import com.learnova.enrollment.dto.EnrollmentResponse;
import com.learnova.enrollment.dto.EnrollmentStatsResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class EnrollmentRepository {

    private static final String MY_COURSES_SQL = """
            SELECT e.id              AS enrollment_id,
                   e.course_id       AS entity_id,
                   c.title           AS entity_title,
                   e.status,
                   e.progress_pct,
                   e.source,
                   e.enrolled_at,
                   e.completed_at
            FROM enrollments e
            JOIN courses c ON c.id = e.course_id
            WHERE e.user_id = ?
            ORDER BY e.enrolled_at DESC
            """;

    private static final String MY_TRACKS_SQL = """
            SELECT te.id             AS enrollment_id,
                   te.track_id       AS entity_id,
                   t.title           AS entity_title,
                   te.status,
                   te.progress_pct,
                   te.enrolled_at,
                   te.completed_at
            FROM track_enrollments te
            JOIN tracks t ON t.id = te.track_id
            WHERE te.user_id = ?
            ORDER BY te.enrolled_at DESC
            """;

    private static final String COURSE_ACCESS_SQL = """
            SELECT is_accessible     AS accessible,
                   reason_code,
                   reason,
                   enrollment_status,
                   progress_pct,
                   blocking_course_id,
                   blocking_course_title
            FROM fn_student_course_access(?, ?)
            """;

    private static final String STATS_SQL = """
            SELECT total_users,
                   active_students,
                   total_courses,
                   published_courses,
                   total_enrollments,
                   active_enrollments,
                   completed_enrollments,
                   distinct_students
            FROM fn_admin_enrollment_stats()
            """;

    private final JdbcTemplate jdbcTemplate;

    public EnrollmentRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<EnrollmentResponse> findMyCourses(Long studentId) {
        return jdbcTemplate.query(MY_COURSES_SQL, courseRowMapper(), studentId);
    }

    public List<EnrollmentResponse> findMyTracks(Long studentId) {
        return jdbcTemplate.query(MY_TRACKS_SQL, trackRowMapper(), studentId);
    }

    public DatabaseAccessResult findCourseAccess(Long studentId, Long courseId) {
        List<DatabaseAccessResult> results = jdbcTemplate.query(
                COURSE_ACCESS_SQL,
                accessMapper(),
                studentId,
                courseId
        );
        return results.isEmpty() ? null : results.get(0);
    }

    public EnrollmentStatsResponse getStats() {
        List<EnrollmentStatsResponse> results = jdbcTemplate.query(
                STATS_SQL,
                (rs, rowNum) -> {
                    EnrollmentStatsResponse stats = new EnrollmentStatsResponse();
                    stats.setTotalUsers(rs.getLong("total_users"));
                    stats.setActiveStudents(rs.getLong("active_students"));
                    stats.setTotalCourses(rs.getLong("total_courses"));
                    stats.setPublishedCourses(rs.getLong("published_courses"));
                    stats.setTotalEnrollments(rs.getLong("total_enrollments"));
                    stats.setActiveEnrollments(rs.getLong("active_enrollments"));
                    stats.setCompletedEnrollments(rs.getLong("completed_enrollments"));
                    stats.setDistinctStudents(rs.getLong("distinct_students"));
                    return stats;
                }
        );
        return results.isEmpty() ? null : results.get(0);
    }

    private RowMapper<EnrollmentResponse> courseRowMapper() {
        return (rs, rowNum) -> {
            EnrollmentResponse response = new EnrollmentResponse();
            response.setEnrollmentId(rs.getLong("enrollment_id"));
            response.setEntityId(rs.getLong("entity_id"));
            response.setEntityTitle(rs.getString("entity_title"));
            response.setEntityType("COURSE");
            response.setStatus(rs.getString("status"));
            response.setProgressPct(rs.getBigDecimal("progress_pct"));
            response.setSource(rs.getString("source"));
            response.setEnrolledAt(rs.getObject("enrolled_at", OffsetDateTime.class));
            response.setCompletedAt(rs.getObject("completed_at", OffsetDateTime.class));
            return response;
        };
    }

    private RowMapper<EnrollmentResponse> trackRowMapper() {
        return (rs, rowNum) -> {
            EnrollmentResponse response = new EnrollmentResponse();
            response.setEnrollmentId(rs.getLong("enrollment_id"));
            response.setEntityId(rs.getLong("entity_id"));
            response.setEntityTitle(rs.getString("entity_title"));
            response.setEntityType("TRACK");
            response.setStatus(rs.getString("status"));
            response.setProgressPct(rs.getBigDecimal("progress_pct"));
            response.setSource("track");
            response.setEnrolledAt(rs.getObject("enrolled_at", OffsetDateTime.class));
            response.setCompletedAt(rs.getObject("completed_at", OffsetDateTime.class));
            return response;
        };
    }

    private RowMapper<DatabaseAccessResult> accessMapper() {
        return (rs, rowNum) -> {
            DatabaseAccessResult result = new DatabaseAccessResult();
            result.setAccessible(rs.getBoolean("accessible"));
            result.setReasonCode(rs.getString("reason_code"));
            result.setReason(rs.getString("reason"));
            result.setEnrollmentStatus(rs.getString("enrollment_status"));
            result.setProgressPct(rs.getBigDecimal("progress_pct"));
            long blockingCourseId = rs.getLong("blocking_course_id");
            result.setBlockingCourseId(rs.wasNull() ? null : blockingCourseId);
            result.setBlockingCourseTitle(rs.getString("blocking_course_title"));
            return result;
        };
    }
}
