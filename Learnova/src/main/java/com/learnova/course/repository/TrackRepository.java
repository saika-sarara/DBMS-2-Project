package com.learnova.course.repository;

import com.learnova.course.dto.TrackCourseResponse;
import com.learnova.course.dto.TrackResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Repository
public class TrackRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public TrackRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<TrackResponse> findPublished() {
        List<TrackResponse> tracks = jdbcTemplate.query(
                """
                SELECT id, title, description, status
                FROM public.tracks
                WHERE status = 'PUBLISHED'
                ORDER BY title
                """,
                new MapSqlParameterSource(),
                (rs, rowNum) -> new TrackResponse(
                        rs.getLong("id"),
                        rs.getString("title"),
                        rs.getString("description"),
                        rs.getString("status"),
                        List.of()
                )
        );

        return attachCourses(tracks);
    }

    public TrackResponse findPublishedById(Long trackId) {
        List<TrackResponse> tracks = jdbcTemplate.query(
                """
                SELECT id, title, description, status
                FROM public.tracks
                WHERE id = :trackId AND status = 'PUBLISHED'
                """,
                new MapSqlParameterSource("trackId", trackId),
            (rs, rowNum) -> new TrackResponse(
                rs.getLong("id"),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("status"),
                List.of()
            )
        );

        return tracks.isEmpty() ? null : attachCourses(tracks).get(0);
    }

    private List<TrackResponse> attachCourses(List<TrackResponse> tracks) {
        if (tracks.isEmpty()) {
            return tracks;
        }

        Map<Long, List<TrackCourseResponse>> coursesByTrack = jdbcTemplate.query(
                """
            SELECT tc.track_id, c.id AS course_id, c.title, c.short_description,
                       tc.sequence_order
                FROM public.track_courses tc
                JOIN public.courses c ON c.id = tc.course_id
            WHERE tc.track_id IN (:trackIds) AND c.status = 'PUBLISHED'
            ORDER BY tc.track_id, tc.sequence_order, c.id
                """,
                new MapSqlParameterSource("trackIds", tracks.stream()
                        .map(TrackResponse::id)
                        .toList()),
                (rs, rowNum) -> Map.entry(
                        rs.getLong("track_id"),
                        new TrackCourseResponse(
                                rs.getLong("course_id"),
                                rs.getString("title"),
                                rs.getString("short_description"),
                                rs.getInt("sequence_order")
                        )
                )
        ).stream().collect(Collectors.groupingBy(
                Map.Entry::getKey,
                LinkedHashMap::new,
                Collectors.mapping(Map.Entry::getValue, Collectors.toList())
        ));

        return tracks.stream()
                .map(track -> new TrackResponse(
                        track.id(),
                        track.title(),
                        track.description(),
                        track.status(),
                        coursesByTrack.getOrDefault(track.id(), List.of())
                ))
                .toList();
    }
}
