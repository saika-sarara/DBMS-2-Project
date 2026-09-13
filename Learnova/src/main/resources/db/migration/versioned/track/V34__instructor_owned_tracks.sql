-- Instructor-owned learning tracks. Tracks remain private until an admin
-- approves the instructor submission and publishes them.
ALTER TABLE public.tracks
    ADD COLUMN IF NOT EXISTS instructor_id BIGINT
        REFERENCES public.users (id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_tracks_instructor_id
    ON public.tracks (instructor_id);

CREATE OR REPLACE FUNCTION public.sp_track_create(
    p_actor_id BIGINT,
    p_title TEXT,
    p_description TEXT,
    p_course_ids JSONB DEFAULT '[]'::JSONB
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE v_track_id BIGINT;
BEGIN
    IF NOT public.fn_user_has_role(p_actor_id, 'INSTRUCTOR') THEN
        RAISE EXCEPTION 'LTT02: Only instructors can create tracks.' USING ERRCODE = 'LTT02';
    END IF;
    IF BTRIM(COALESCE(p_title, '')) = '' THEN
        RAISE EXCEPTION 'LTT03: Track title is required.' USING ERRCODE = 'LTT03';
    END IF;

    INSERT INTO public.tracks (title, description, status, instructor_id)
    VALUES (BTRIM(p_title), NULLIF(BTRIM(p_description), ''), 'DRAFT', p_actor_id)
    RETURNING id INTO v_track_id;

    PERFORM public.sp_track_replace_courses(p_actor_id, v_track_id, p_course_ids);
    RETURN v_track_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_track_replace_courses(
    p_actor_id BIGINT,
    p_track_id BIGINT,
    p_course_ids JSONB
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE v_status TEXT; v_owner BIGINT; v_count INTEGER;
BEGIN
    SELECT status, instructor_id INTO v_status, v_owner FROM public.tracks WHERE id = p_track_id;
    IF v_owner IS NULL OR v_owner <> p_actor_id THEN
        RAISE EXCEPTION 'LTT04: Track % is not owned by this instructor.', p_track_id USING ERRCODE = 'LTT04';
    END IF;
    IF v_status <> 'DRAFT' THEN
        RAISE EXCEPTION 'LTT05: Only draft tracks can be edited.' USING ERRCODE = 'LTT05';
    END IF;
    IF p_course_ids IS NULL OR jsonb_typeof(p_course_ids) <> 'array' THEN
        RAISE EXCEPTION 'LTT06: Course ids must be an array.' USING ERRCODE = 'LTT06';
    END IF;
    SELECT COUNT(*) INTO v_count FROM jsonb_array_elements_text(p_course_ids);
    IF v_count <> (SELECT COUNT(DISTINCT value::BIGINT) FROM jsonb_array_elements_text(p_course_ids)) THEN
        RAISE EXCEPTION 'LTT06: A course can appear only once in a track.' USING ERRCODE = 'LTT06';
    END IF;
    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(p_course_ids) WITH ORDINALITY ids(value, ord)
        LEFT JOIN public.courses c ON c.id = ids.value::BIGINT
        WHERE c.id IS NULL OR c.instructor_id <> p_actor_id
    ) THEN
        RAISE EXCEPTION 'LTT07: Tracks can contain only courses owned by the instructor.' USING ERRCODE = 'LTT07';
    END IF;
    DELETE FROM public.track_courses WHERE track_id = p_track_id;
    INSERT INTO public.track_courses (track_id, course_id, sequence_order)
    SELECT p_track_id, ids.value::BIGINT, ids.ord::INTEGER
    FROM jsonb_array_elements_text(p_course_ids) WITH ORDINALITY ids(value, ord);
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_track_submit(p_actor_id BIGINT, p_track_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_status TEXT; v_owner BIGINT;
BEGIN
    SELECT status, instructor_id INTO v_status, v_owner FROM public.tracks WHERE id = p_track_id;
    IF v_owner IS NULL OR v_owner <> p_actor_id THEN RAISE EXCEPTION 'LTT04: Track is not owned by this instructor.' USING ERRCODE = 'LTT04'; END IF;
    IF v_status <> 'DRAFT' THEN RAISE EXCEPTION 'LTT05: Only draft tracks can be submitted.' USING ERRCODE = 'LTT05'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.track_courses WHERE track_id = p_track_id) THEN RAISE EXCEPTION 'LTT08: A track needs at least one course.' USING ERRCODE = 'LTT08'; END IF;
    IF EXISTS (SELECT 1 FROM public.track_courses tc JOIN public.courses c ON c.id = tc.course_id WHERE tc.track_id = p_track_id AND c.status <> 'PUBLISHED') THEN
        RAISE EXCEPTION 'LTT09: Every course must be published before track approval.' USING ERRCODE = 'LTT09';
    END IF;
    UPDATE public.tracks SET status = 'PENDING', updated_at = CURRENT_TIMESTAMP WHERE id = p_track_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_track_publish(p_actor_id BIGINT, p_track_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN RAISE EXCEPTION 'LTT10: Only administrators can approve tracks.' USING ERRCODE = 'LTT10'; END IF;
    UPDATE public.tracks SET status = 'PUBLISHED', updated_at = CURRENT_TIMESTAMP WHERE id = p_track_id AND status = 'PENDING';
    IF NOT FOUND THEN RAISE EXCEPTION 'LTT11: Pending track % was not found.', p_track_id USING ERRCODE = 'LTT11'; END IF;
END;
$$;

-- The V32 SQL learning-path courses form one ordered, approved track.
INSERT INTO public.tracks (title, description, status, instructor_id)
SELECT 'SQL Learning Path', 'A guided progression from SQL foundations to performance tuning.', 'PUBLISHED', u.id
FROM public.users u
WHERE u.email = 'saikasarara@gmail.com'
  AND NOT EXISTS (SELECT 1 FROM public.tracks t WHERE t.title = 'SQL Learning Path');

INSERT INTO public.track_courses (track_id, course_id, sequence_order)
SELECT t.id, c.id,
       CASE c.slug WHEN 'basic-sql' THEN 1 WHEN 'intermediate-sql' THEN 2 WHEN 'advanced-sql' THEN 3 END
FROM public.tracks t
JOIN public.courses c ON c.slug IN ('basic-sql', 'intermediate-sql', 'advanced-sql')
WHERE t.title = 'SQL Learning Path'
ON CONFLICT (track_id, course_id) DO UPDATE SET sequence_order = EXCLUDED.sequence_order;
