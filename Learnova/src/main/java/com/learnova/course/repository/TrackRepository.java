package com.learnova.course.repository;

import com.learnova.course.dto.TrackCourseResponse;
import com.learnova.course.dto.TrackResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class TrackRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public TrackRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<TrackResponse> findPublished() {
        return jdbcTemplate.query(
                """
                SELECT id, title, description, status
                FROM public.tracks
                WHERE status = 'PUBLISHED'
                ORDER BY title
                """,
                new MapSqlParameterSource(),
                (rs, rowNum) -> toTrack(rs.getLong("id"), rs.getString("title"),
                        rs.getString("description"), rs.getString("status"),
                        findCourses(rs.getLong("id")))
        );
    }

    public TrackResponse findPublishedById(Long trackId) {
        List<TrackResponse> tracks = jdbcTemplate.query(
                """
                SELECT id, title, description, status
                FROM public.tracks
                WHERE id = :trackId AND status = 'PUBLISHED'
                """,
                new MapSqlParameterSource("trackId", trackId),
                (rs, rowNum) -> toTrack(rs.getLong("id"), rs.getString("title"),
                        rs.getString("description"), rs.getString("status"),
                        findCourses(rs.getLong("id")))
        );
        return tracks.isEmpty() ? null : tracks.get(0);
    }

    private List<TrackCourseResponse> findCourses(Long trackId) {
        return jdbcTemplate.query(
                """
                SELECT c.id AS course_id, c.title, c.short_description,
                       tc.sequence_order
                FROM public.track_courses tc
                JOIN public.courses c ON c.id = tc.course_id
                WHERE tc.track_id = :trackId AND c.status = 'published'
                ORDER BY tc.sequence_order, c.id
                """,
                new MapSqlParameterSource("trackId", trackId),
                (rs, rowNum) -> new TrackCourseResponse(
                        rs.getLong("course_id"),
                        rs.getString("title"),
                        rs.getString("short_description"),
                        rs.getInt("sequence_order")
                )
        );
    }

    private TrackResponse toTrack(
            Long id,
            String title,
            String description,
            String status,
            List<TrackCourseResponse> courses
    ) {
        return new TrackResponse(id, title, description, status, courses);
    }
}