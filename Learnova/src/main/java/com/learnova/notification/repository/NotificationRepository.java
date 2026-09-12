package com.learnova.notification.repository;

import com.learnova.notification.dto.NotificationResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class NotificationRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public NotificationRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<NotificationResponse> findByUser(Long userId) {
        return jdbcTemplate.query(
                """
                SELECT id, message, is_read, related_entity_type,
                       related_entity_id, created_at
                FROM public.notifications
                WHERE user_id = :userId
                ORDER BY created_at DESC, id DESC
                """,
                new MapSqlParameterSource("userId", userId),
                (rs, rowNum) -> new NotificationResponse(
                        rs.getLong("id"),
                        rs.getString("message"),
                        rs.getBoolean("is_read"),
                        rs.getString("related_entity_type"),
                        (Long) rs.getObject("related_entity_id"),
                        rs.getObject("created_at", OffsetDateTime.class)
                )
        );
    }

    public void markRead(Long notificationId, Long userId) {
        jdbcTemplate.queryForObject(
                """
                SELECT notification_id
                FROM public.sp_mark_notification_read(:notificationId, :userId)
                """,
                new MapSqlParameterSource()
                        .addValue("notificationId", notificationId)
                        .addValue("userId", userId),
                Long.class
        );
    }

    public long markAllRead(Long userId) {
        Long count = jdbcTemplate.queryForObject(
                "SELECT public.sp_mark_all_notifications_read(:userId)",
                new MapSqlParameterSource("userId", userId),
                Long.class
        );
        return count == null ? 0L : count;
    }
}
