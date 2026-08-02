package com.learnova.enrollment.repository;

import com.learnova.enrollment.dto.DatabaseEnrollmentResult;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class EnrollmentCommandRepository {

    private static final String ENROLL_IN_COURSE_SQL =
            "SELECT * FROM sp_enroll_student(?, ?, ?)";

    private static final String ENROLL_IN_TRACK_SQL =
            "SELECT * FROM sp_enroll_track(?, ?)";

    private final JdbcTemplate jdbcTemplate;

    public EnrollmentCommandRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public DatabaseEnrollmentResult enrollInCourse(Long studentId, Long courseId) {
        List<DatabaseEnrollmentResult> results = jdbcTemplate.query(
                ENROLL_IN_COURSE_SQL,
                enrollmentMapper(),
                studentId,
                courseId,
                "standalone"
        );
        return results.isEmpty() ? null : results.get(0);
    }

    public DatabaseEnrollmentResult enrollInTrack(Long studentId, Long trackId) {
        List<DatabaseEnrollmentResult> results = jdbcTemplate.query(
                ENROLL_IN_TRACK_SQL,
                enrollmentMapper(),
                studentId,
                trackId
        );
        return results.isEmpty() ? null : results.get(0);
    }

    private RowMapper<DatabaseEnrollmentResult> enrollmentMapper() {
        return (rs, rowNum) -> {
            DatabaseEnrollmentResult result = new DatabaseEnrollmentResult();
            result.setEnrollmentId(rs.getLong("enrollment_id"));
            result.setEntityId(rs.getLong("entity_id"));
            result.setEntityTitle(rs.getString("entity_title"));
            result.setStatus(rs.getString("status"));
            result.setProgressPct(rs.getBigDecimal("progress_pct"));
            result.setSource(rs.getString("source"));
            result.setEnrolledAt(rs.getObject("enrolled_at", OffsetDateTime.class));
            result.setAlreadyEnrolled(rs.getBoolean("already_enrolled"));
            return result;
        };
    }
}
