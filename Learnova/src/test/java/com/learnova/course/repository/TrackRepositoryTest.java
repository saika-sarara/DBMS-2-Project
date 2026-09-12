package com.learnova.course.repository;

import com.learnova.course.dto.TrackResponse;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.ArgumentCaptor;

class TrackRepositoryTest {

    private final NamedParameterJdbcTemplate jdbcTemplate = mock(NamedParameterJdbcTemplate.class);
    private final TrackRepository repository = new TrackRepository(jdbcTemplate);

    @Test
    void findPublishedLoadsCoursesWithOneBatchQueryAndPreservesGrouping() throws Exception {
        List<String> sqlCalls = new ArrayList<>();

        doAnswer(invocation -> {
            String sql = invocation.getArgument(0);
            sqlCalls.add(sql);
            RowMapper<?> mapper = invocation.getArgument(2);

            if (sql.contains("FROM public.tracks")) {
                return List.of(
                        mapParent(mapper, 1L, "Alpha", "First", "PUBLISHED"),
                        mapParent(mapper, 2L, "Beta", "Second", "PUBLISHED"),
                        mapParent(mapper, 3L, "Gamma", "Third", "PUBLISHED")
                );
            }

            return List.of(
                    mapCourse(mapper, 1L, 11L, "Alpha One", "A1", 1),
                    mapCourse(mapper, 3L, 30L, "Gamma First", "G0", 1),
                    mapCourse(mapper, 3L, 31L, "Gamma One", "G1", 2)
            );
        }).when(jdbcTemplate).query(
                anyString(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );

        List<TrackResponse> tracks = repository.findPublished();

        assertEquals(List.of(1L, 2L, 3L), tracks.stream().map(TrackResponse::id).toList());
        assertEquals(List.of(11L), tracks.get(0).courses().stream()
                .map(course -> course.courseId()).toList());
        assertTrue(tracks.get(1).courses().isEmpty());
        assertEquals(List.of(30L, 31L), tracks.get(2).courses().stream()
                .map(course -> course.courseId()).toList());
        assertEquals(List.of(1, 2), tracks.get(2).courses().stream()
                .map(course -> course.sequenceOrder()).toList());

        verify(jdbcTemplate, times(2)).query(
                anyString(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );
        assertEquals(2, sqlCalls.size());
        assertTrue(sqlCalls.get(1).contains("IN (:trackIds)"));
    }

    @Test
    void findPublishedReturnsEmptyWithoutCourseQueryWhenNoTracksExist() {
        doAnswer(invocation -> List.of())
                .when(jdbcTemplate).query(
                        anyString(),
                        any(MapSqlParameterSource.class),
                        any(RowMapper.class)
                );

        assertTrue(repository.findPublished().isEmpty());

        verify(jdbcTemplate, times(1)).query(
                anyString(),
                any(MapSqlParameterSource.class),
                any(RowMapper.class)
        );
    }

    private TrackResponse mapParent(
            RowMapper<?> mapper,
            Long id,
            String title,
            String description,
            String status
    ) throws Exception {
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getLong("id")).thenReturn(id);
        when(resultSet.getString("title")).thenReturn(title);
        when(resultSet.getString("description")).thenReturn(description);
        when(resultSet.getString("status")).thenReturn(status);
        return (TrackResponse) mapper.mapRow(resultSet, 0);
    }

    private Object mapCourse(
            RowMapper<?> mapper,
            Long trackId,
            Long courseId,
            String title,
            String description,
            int sequenceOrder
    ) throws Exception {
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getLong("track_id")).thenReturn(trackId);
        when(resultSet.getLong("course_id")).thenReturn(courseId);
        when(resultSet.getString("title")).thenReturn(title);
        when(resultSet.getString("short_description")).thenReturn(description);
        when(resultSet.getInt("sequence_order")).thenReturn(sequenceOrder);
        return mapper.mapRow(resultSet, 0);
    }
}
