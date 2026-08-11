-- =========================================================
-- fn_certificate_verify
--
-- FUNCTION for the certificate feature.
-- Source of truth: certificate.sql (V12). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Verification lookup
-- Public lookup by certificate code; used by the verify page.

CREATE OR REPLACE FUNCTION public.fn_certificate_verify(p_cert_code VARCHAR)
RETURNS TABLE (
    certificate_id BIGINT,
    cert_code      VARCHAR,
    type           VARCHAR,
    holder_name    TEXT,
    entity_title   TEXT,
    issued_at      TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.id,
        c.cert_code,
        c.type,
        CONCAT_WS(' ', u.first_name, u.last_name),
        CASE
            WHEN c.type = 'course'
                THEN co.title
            WHEN c.type = 'track'
                THEN t.title
        END,
        c.issued_at
    FROM public.certificates c
    JOIN public.users u ON u.id = c.user_id
    LEFT JOIN public.courses co ON co.id = c.course_id
    LEFT JOIN public.tracks t ON t.id = c.track_id
    WHERE c.cert_code = BTRIM(p_cert_code);
$$;
