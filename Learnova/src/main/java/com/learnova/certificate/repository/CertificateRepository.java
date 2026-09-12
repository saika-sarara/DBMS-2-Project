package com.learnova.certificate.repository;

import com.learnova.certificate.dto.CertificateResponse;
import com.learnova.certificate.dto.CertificateVerificationResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class CertificateRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CertificateRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<CertificateResponse> findByUser(Long userId) {
        return jdbcTemplate.query(
                """
                SELECT id AS certificate_id, user_id, type, course_id, track_id,
                       cert_code, issued_at
                FROM public.certificates
                WHERE user_id = :userId
                ORDER BY issued_at DESC
                """,
                new MapSqlParameterSource("userId", userId),
                (rs, rowNum) -> new CertificateResponse(
                        rs.getLong("certificate_id"),
                        rs.getLong("user_id"),
                        rs.getString("type"),
                        (Long) rs.getObject("course_id"),
                        (Long) rs.getObject("track_id"),
                        rs.getString("cert_code"),
                        rs.getObject("issued_at", OffsetDateTime.class),
                        false
                )
        );
    }

    public CertificateResponse issue(Long userId, String type, Long entityId) {
        return jdbcTemplate.queryForObject(
                """
                SELECT certificate_id, user_id, type, course_id, track_id,
                       cert_code, issued_at, already_issued
                FROM public.sp_issue_certificate(:userId, :type, :entityId)
                """,
                new MapSqlParameterSource()
                        .addValue("userId", userId)
                        .addValue("type", type)
                        .addValue("entityId", entityId),
                (rs, rowNum) -> new CertificateResponse(
                        rs.getLong("certificate_id"),
                        rs.getLong("user_id"),
                        rs.getString("type"),
                        (Long) rs.getObject("course_id"),
                        (Long) rs.getObject("track_id"),
                        rs.getString("cert_code"),
                        rs.getObject("issued_at", OffsetDateTime.class),
                        rs.getBoolean("already_issued")
                )
        );
    }

    public CertificateVerificationResponse verify(String code) {
        List<CertificateVerificationResponse> matches = jdbcTemplate.query(
                """
                SELECT certificate_id, cert_code, type, holder_name,
                       entity_title, issued_at
                FROM public.fn_certificate_verify(:code)
                """,
                new MapSqlParameterSource("code", code),
                (rs, rowNum) -> new CertificateVerificationResponse(
                        rs.getLong("certificate_id"),
                        rs.getString("cert_code"),
                        rs.getString("type"),
                        rs.getString("holder_name"),
                        rs.getString("entity_title"),
                        rs.getObject("issued_at", OffsetDateTime.class)
                )
        );
        return matches.isEmpty() ? null : matches.get(0);
    }
}