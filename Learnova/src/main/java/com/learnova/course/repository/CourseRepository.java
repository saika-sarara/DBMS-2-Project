package com.learnova.course.repository;

import com.learnova.course.dto.CourseCardResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;

@Repository
public class CourseRepository {

    private static final String SEARCH_COURSES_SQL = """
            SELECT *
            FROM public.fn_search_public_course_catalogue(
                :search,
                :categoryId,
                :difficulty,
                :sort,
                :limit,
                :offset
            )
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CourseRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public SearchResult search(
            String search,
            Long categoryId,
            String difficulty,
            String sort,
            int limit,
            int offset
    ) {
        MapSqlParameterSource parameters = createParameters(
                search,
                categoryId,
                difficulty,
                sort,
                limit,
                offset
        );

        List<CourseRow> rows = jdbcTemplate.query(
                SEARCH_COURSES_SQL,
                parameters,
                (resultSet, rowNumber) -> new CourseRow(
                        mapCourse(resultSet),
                        resultSet.getLong("total_count")
                )
        );

        if (rows.isEmpty()) {
            /*
             * COUNT(*) OVER() is included in every returned row.
             * When an out-of-range page returns no rows, there is no row
             * from which Java can read total_count.
             *
             * In that case, call the same PostgreSQL function again with
             * limit 1 and offset 0. PostgreSQL still owns all filtering and
             * visibility rules.
             */
            long totalElements = offset > 0
                    ? loadTotalCount(
                            search,
                            categoryId,
                            difficulty,
                            sort
                    )
                    : 0L;

            return new SearchResult(List.of(), totalElements);
        }

        List<CourseCardResponse> courses = rows.stream()
                .map(CourseRow::course)
                .toList();

        long totalElements = rows.get(0).totalCount();

        return new SearchResult(courses, totalElements);
    }

    private long loadTotalCount(
            String search,
            Long categoryId,
            String difficulty,
            String sort
    ) {
        MapSqlParameterSource parameters = createParameters(
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

    private MapSqlParameterSource createParameters(
            String search,
            Long categoryId,
            String difficulty,
            String sort,
            int limit,
            int offset
    ) {
        return new MapSqlParameterSource()
                .addValue("search", search)
                .addValue("categoryId", categoryId)
                .addValue("difficulty", difficulty)
                .addValue("sort", sort)
                .addValue("limit", limit)
                .addValue("offset", offset);
    }

    private CourseCardResponse mapCourse(
            ResultSet resultSet
    ) throws SQLException {
        Object categoryIdValue = resultSet.getObject("category_id");

        Long categoryId = categoryIdValue == null
                ? null
                : resultSet.getLong("category_id");

        String databaseDifficulty =
                resultSet.getString("difficulty");

        String apiDifficulty = databaseDifficulty == null
                ? null
                : databaseDifficulty.toLowerCase(Locale.ROOT);

        BigDecimal averageRating =
                resultSet.getBigDecimal("avg_rating");

        OffsetDateTime publishedAt = resultSet.getObject(
                "published_at",
                OffsetDateTime.class
        );

        return new CourseCardResponse(
                resultSet.getLong("course_id"),
                resultSet.getLong("course_id"),
                resultSet.getString("title"),
                resultSet.getString("slug"),
                resultSet.getString("short_description"),
                resultSet.getString("thumbnail_url"),
                apiDifficulty,
                categoryId,
                resultSet.getString("category_name"),
                averageRating,
                resultSet.getInt("review_count"),
                publishedAt,
                resultSet.getDouble("rank_score")
        );
    }

    private record CourseRow(
            CourseCardResponse course,
            long totalCount
    ) {
    }

    public record SearchResult(
            List<CourseCardResponse> content,
            long totalElements
    ) {
        public SearchResult {
            content = List.copyOf(content);
        }
    }
}