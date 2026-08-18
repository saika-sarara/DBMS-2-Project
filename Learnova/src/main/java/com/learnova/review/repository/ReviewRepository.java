package com.learnova.review.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class ReviewRepository {

    private static final String REVIEW_STATE_SQL = """
            SELECT *
            FROM public.fn_course_review_state(
                CAST(:studentId AS BIGINT),
                CAST(:courseId AS BIGINT)
            )
            """;

    private static final String CREATE_REVIEW_SQL = """
            SELECT *
            FROM public.sp_create_review(
                CAST(:studentId AS BIGINT),
                CAST(:courseId AS BIGINT),
                CAST(:rating AS SMALLINT),
                CAST(:comment AS TEXT)
            )
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public ReviewRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public ReviewStateRow findReviewState(Long studentId, Long courseId) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("courseId", courseId);

        List<ReviewStateRow> rows = jdbcTemplate.query(
                REVIEW_STATE_SQL,
                parameters,
                (resultSet, rowNumber) -> new ReviewStateRow(
                        resultSet.getLong("course_id"),
                        resultSet.getBigDecimal("avg_rating"),
                        resultSet.getInt("review_count"),
                        resultSet.getString("review_state"),
                        resultSet.getBoolean("can_review"),
                        resultSet.getString("own_review"),
                        resultSet.getString("reviews")
                )
        );

        return rows.isEmpty() ? null : rows.get(0);
    }

    public CreatedReviewRow createReview(Long studentId, Long courseId, Integer rating, String comment) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("studentId", studentId)
                .addValue("courseId", courseId)
                .addValue("rating", rating)
                .addValue("comment", comment);

        return jdbcTemplate.queryForObject(
                CREATE_REVIEW_SQL,
                parameters,
                (resultSet, rowNumber) -> new CreatedReviewRow(
                        resultSet.getLong("review_id"),
                        resultSet.getLong("user_id"),
                        resultSet.getLong("course_id"),
                        resultSet.getInt("rating"),
                        resultSet.getString("comment"),
                        resultSet.getObject("created_at", OffsetDateTime.class),
                        resultSet.getObject("updated_at", OffsetDateTime.class)
                )
        );
    }

    public record ReviewStateRow(
            Long courseId,
            BigDecimal avgRating,
            int reviewCount,
            String reviewState,
            boolean canReview,
            String ownReviewJson,
            String reviewsJson
    ) {}

    public record CreatedReviewRow(
            Long reviewId,
            Long userId,
            Long courseId,
            Integer rating,
            String comment,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {}
}