-- =========================================================
-- V4: Course management
--
-- All schema for the course-authoring feature in one file:
--   * the courses table (full final shape: lifecycle, catalogue
--     fields, aggregates) and the lessons / modules /
--     lesson_content_blocks / course_tags / course_tag_map tables
--   * DB-owned lifecycle + ownership + validation rules
--   * every authoring procedure, using the FIXED implementations
--     (ambiguous-column fixes, qualified MAX(sequence_order),
--     lessons.updated_at mapped into the created_at OUT param)
--   * course indexes
--
-- The catalogue trigger that maintains slug / search_vector /
-- published_at lives in V5 (catalogue feature); it is in place
-- before any course row is inserted by the seed migration.
-- =========================================================

-- =========================================================
-- 1. Courses (cross-module core contract)
-- =========================================================

CREATE TABLE public.courses (
    id                         BIGSERIAL PRIMARY KEY,
    title                      VARCHAR(255) NOT NULL,
    status                     VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    description                TEXT,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    category_id                BIGINT NOT NULL,
    slug                       VARCHAR(255) NOT NULL,
    short_description          VARCHAR(500),
    thumbnail_url              TEXT,
    difficulty                 VARCHAR(20) NOT NULL DEFAULT 'BEGINNER',
    avg_rating                 NUMERIC(3,2) NOT NULL DEFAULT 0.00,
    review_count               INTEGER NOT NULL DEFAULT 0,
    published_at               TIMESTAMPTZ,
    search_vector              TSVECTOR NOT NULL,
    instructor_id              BIGINT NOT NULL,
    submitted_at               TIMESTAMPTZ,
    published_by               BIGINT,
    rejection_reason           TEXT,
    total_lessons              INTEGER NOT NULL DEFAULT 0,
    estimated_duration_minutes INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_courses_status
        CHECK (status IN (
            'DRAFT',
            'PENDING_REVIEW',
            'PUBLISHED',
            'REJECTED',
            'ARCHIVED'
        )),

    CONSTRAINT chk_courses_difficulty
        CHECK (
            difficulty IN (
                'BEGINNER',
                'INTERMEDIATE',
                'ADVANCED'
            )
        ),

    CONSTRAINT chk_courses_avg_rating
        CHECK (
            avg_rating >= 0.00
            AND avg_rating <= 5.00
        ),

    CONSTRAINT chk_courses_review_count
        CHECK (
            review_count >= 0
        ),

    CONSTRAINT chk_courses_total_lessons
        CHECK (total_lessons >= 0),

    CONSTRAINT chk_courses_duration
        CHECK (estimated_duration_minutes >= 0),

    CONSTRAINT uq_courses_slug
        UNIQUE (slug),

    CONSTRAINT fk_courses_category
        FOREIGN KEY (category_id)
        REFERENCES public.categories (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_courses_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES public.users (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_courses_published_by
        FOREIGN KEY (published_by)
        REFERENCES public.users (id)
        ON DELETE SET NULL
);


-- =========================================================
-- 2. Modules
-- =========================================================

CREATE TABLE public.modules (
    id             BIGSERIAL PRIMARY KEY,
    course_id      BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    title          VARCHAR(255) NOT NULL,
    description    TEXT,
    sequence_order INTEGER NOT NULL CHECK (sequence_order > 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_modules_course_sequence
        UNIQUE (course_id, sequence_order),

    CONSTRAINT chk_modules_title_not_blank
        CHECK (btrim(title) <> '')
);

CREATE TRIGGER trg_modules_set_updated_at
BEFORE UPDATE ON public.modules
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 3. Lessons (module scoping + preview + duration)
-- =========================================================

CREATE TABLE public.lessons (
    id                         BIGSERIAL PRIMARY KEY,
    course_id                  BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    title                      VARCHAR(255) NOT NULL,
    sequence_order             INT NOT NULL DEFAULT 0,
    module_id                  BIGINT REFERENCES public.modules (id) ON DELETE CASCADE,
    description                TEXT,
    estimated_duration_minutes INTEGER NOT NULL DEFAULT 0,
    is_preview                 BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_lessons_module_sequence
        UNIQUE (module_id, sequence_order),

    CONSTRAINT chk_lessons_duration
        CHECK (estimated_duration_minutes >= 0),

    CONSTRAINT chk_lessons_title_not_blank
        CHECK (btrim(title) <> ''),

    CONSTRAINT chk_lessons_sequence_positive
        CHECK (sequence_order > 0)
);

CREATE TRIGGER trg_lessons_set_updated_at
BEFORE UPDATE ON public.lessons
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 4. Lesson content blocks
-- =========================================================

CREATE TABLE public.lesson_content_blocks (
    id             BIGSERIAL PRIMARY KEY,
    lesson_id      BIGINT NOT NULL REFERENCES public.lessons (id) ON DELETE CASCADE,
    block_type     VARCHAR(20) NOT NULL,
    title          VARCHAR(255),
    body_markdown  TEXT,
    resource_url   TEXT,
    sequence_order INTEGER NOT NULL CHECK (sequence_order > 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_content_blocks_lesson_sequence
        UNIQUE (lesson_id, sequence_order),

    CONSTRAINT chk_content_blocks_type
        CHECK (block_type IN (
            'markdown',
            'youtube',
            'pdf',
            'link',
            'image',
            'code'
        ))
);

CREATE TRIGGER trg_content_blocks_set_updated_at
BEFORE UPDATE ON public.lesson_content_blocks
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 5. Course tags (optional enrichment, read-only via APIs)
-- =========================================================

CREATE TABLE public.course_tags (
    id   BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(150) NOT NULL,

    CONSTRAINT uq_course_tags_name UNIQUE (name),
    CONSTRAINT uq_course_tags_slug UNIQUE (slug)
);

CREATE TABLE public.course_tag_map (
    course_id BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    tag_id    BIGINT NOT NULL REFERENCES public.course_tags (id) ON DELETE CASCADE,

    CONSTRAINT pk_course_tag_map PRIMARY KEY (course_id, tag_id)
);

CREATE INDEX idx_course_tag_map_tag
    ON public.course_tag_map (tag_id);


-- =========================================================
-- 6. Helper functions (ownership, editability, aggregates)
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_course_is_owned_by(
    p_course_id BIGINT,
    p_user_id   BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_owner_id BIGINT;
BEGIN
    SELECT instructor_id INTO v_owner_id
    FROM public.courses
    WHERE id = p_course_id;

    RETURN v_owner_id IS NOT NULL AND v_owner_id = p_user_id;
END;
$$;

-- A course may only be edited while it is still being authored.
CREATE OR REPLACE FUNCTION public.fn_course_is_editable(p_course_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.courses
        WHERE id = p_course_id
          AND status IN ('DRAFT', 'REJECTED')
    );
$$;

CREATE OR REPLACE FUNCTION public.fn_course_lesson_count(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*)::BIGINT
    FROM public.lessons
    WHERE course_id = p_course_id;
$$;

CREATE OR REPLACE FUNCTION public.fn_course_duration_minutes(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(estimated_duration_minutes), 0)::BIGINT
    FROM public.lessons
    WHERE course_id = p_course_id;
$$;

-- Recalculates the denormalized aggregate counters on courses.
CREATE OR REPLACE FUNCTION public.fn_update_course_aggregate_counts(p_course_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.courses
    SET total_lessons = (
            SELECT COUNT(*)::INTEGER
            FROM public.lessons
            WHERE course_id = p_course_id
        ),
        estimated_duration_minutes = (
            SELECT COALESCE(SUM(estimated_duration_minutes), 0)::INTEGER
            FROM public.lessons
            WHERE course_id = p_course_id
        )
    WHERE id = p_course_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_course_tag_list(p_course_id BIGINT)
RETURNS TEXT[]
LANGUAGE sql
STABLE
AS $$
    SELECT ARRAY(
        SELECT ct.name
        FROM public.course_tag_map ctm
        JOIN public.course_tags ct ON ct.id = ctm.tag_id
        WHERE ctm.course_id = p_course_id
        ORDER BY ct.name ASC
    );
$$;

-- Raise a stable LTxxx error unless the caller is allowed.
CREATE OR REPLACE FUNCTION public.fn_require_course_manager(
    p_course_id BIGINT,
    p_actor_id  BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_actor_id IS NULL OR NOT public.fn_user_is_instructor_or_admin(p_actor_id) THEN
        RAISE EXCEPTION 'LTC10: You do not have permission to manage courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF NOT public.fn_course_is_owned_by(p_course_id, p_actor_id)
       AND NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: You can only manage your own courses.'
            USING ERRCODE = 'LTC10';
    END IF;
END;
$$;


-- =========================================================
-- 7. Aggregate + validation triggers
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_refresh_course_aggregates()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    v_course_id := COALESCE(NEW.course_id, OLD.course_id);

    IF v_course_id IS NOT NULL THEN
        PERFORM public.fn_update_course_aggregate_counts(v_course_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_refresh_course_aggregates ON public.lessons;
CREATE TRIGGER trg_refresh_course_aggregates
AFTER INSERT OR UPDATE OF estimated_duration_minutes OR DELETE ON public.lessons
FOR EACH ROW
EXECUTE FUNCTION public.fn_refresh_course_aggregates();

CREATE OR REPLACE FUNCTION public.fn_validate_content_block()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.block_type IN ('markdown', 'code')
       AND (NEW.body_markdown IS NULL OR btrim(NEW.body_markdown) = '') THEN
        RAISE EXCEPTION 'LTC20: A % block requires body_markdown content.', NEW.block_type
            USING ERRCODE = 'LTC20';
    END IF;

    IF NEW.block_type IN ('youtube', 'pdf', 'link', 'image')
       AND (NEW.resource_url IS NULL OR btrim(NEW.resource_url) = '') THEN
        RAISE EXCEPTION 'LTC20: A % block requires a resource_url.', NEW.block_type
            USING ERRCODE = 'LTC20';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_content_block ON public.lesson_content_blocks;
CREATE TRIGGER trg_validate_content_block
BEFORE INSERT OR UPDATE ON public.lesson_content_blocks
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_content_block();


-- =========================================================
-- 8. Course lifecycle procedures
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_create_course_draft(
    p_instructor_id   BIGINT,
    p_category_id     BIGINT,
    p_title           VARCHAR,
    p_short_description VARCHAR,
    p_description     TEXT,
    p_difficulty      VARCHAR,
    p_thumbnail_url   TEXT
)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    instructor_id    BIGINT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_difficulty VARCHAR(20);
BEGIN
    IF NOT public.fn_user_is_instructor_or_admin(p_instructor_id) THEN
        RAISE EXCEPTION 'LTC10: Only instructors and administrators can create courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Course title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    IF p_category_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.categories WHERE id = p_category_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'LTC13: A valid active category is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_difficulty := UPPER(COALESCE(NULLIF(BTRIM(p_difficulty), ''), 'BEGINNER'));

    IF v_difficulty NOT IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED') THEN
        RAISE EXCEPTION 'LTC13: difficulty must be beginner, intermediate or advanced.'
            USING ERRCODE = 'LTC13';
    END IF;

    INSERT INTO public.courses (
        instructor_id,
        category_id,
        title,
        slug,
        short_description,
        description,
        difficulty,
        status,
        thumbnail_url
    )
    VALUES (
        p_instructor_id,
        p_category_id,
        BTRIM(p_title),
        public.fn_generate_unique_course_slug(p_title),
        p_short_description,
        p_description,
        v_difficulty,
        'DRAFT',
        p_thumbnail_url
    )
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.difficulty,
        public.courses.category_id,
        public.courses.instructor_id,
        public.courses.short_description,
        public.courses.description,
        public.courses.thumbnail_url,
        public.courses.created_at,
        public.courses.updated_at
    INTO course_id, title, slug, status, difficulty, category_id, instructor_id,
         short_description, description, thumbnail_url, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC13', '23505', '23502', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_course_draft unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_update_course_basic_info(
    p_actor_id        BIGINT,
    p_course_id       BIGINT,
    p_category_id     BIGINT,
    p_title           VARCHAR,
    p_short_description VARCHAR,
    p_description     TEXT,
    p_difficulty      VARCHAR,
    p_thumbnail_url   TEXT
)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    instructor_id    BIGINT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_difficulty VARCHAR(20);
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Published or archived courses cannot be edited.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Course title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    IF p_category_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.categories WHERE id = p_category_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'LTC13: A valid active category is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_difficulty := UPPER(COALESCE(NULLIF(BTRIM(p_difficulty), ''), 'BEGINNER'));

    IF v_difficulty NOT IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED') THEN
        RAISE EXCEPTION 'LTC13: difficulty must be beginner, intermediate or advanced.'
            USING ERRCODE = 'LTC13';
    END IF;

    UPDATE public.courses
    SET category_id = p_category_id,
        title = BTRIM(p_title),
        short_description = p_short_description,
        description = p_description,
        difficulty = v_difficulty,
        thumbnail_url = p_thumbnail_url
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.difficulty,
        public.courses.category_id,
        public.courses.instructor_id,
        public.courses.short_description,
        public.courses.description,
        public.courses.thumbnail_url,
        public.courses.created_at,
        public.courses.updated_at
    INTO course_id, title, slug, status, difficulty, category_id, instructor_id,
         short_description, description, thumbnail_url, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', '23505', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_course_basic_info unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_submit_course_for_review(
    p_actor_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR,
    submitted_at TIMESTAMPTZ,
    rejection_reason TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status      VARCHAR(20);
    v_module_cnt  BIGINT;
    v_lesson_cnt  BIGINT;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    SELECT c.status, c.rejection_reason
    INTO v_status, rejection_reason
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status = 'ARCHIVED' THEN
        RAISE EXCEPTION 'LTC12: Archived courses cannot be submitted for review.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF v_status NOT IN ('DRAFT', 'REJECTED') THEN
        RAISE EXCEPTION 'LTC12: Course is not in an editable state.'
            USING ERRCODE = 'LTC12';
    END IF;

    SELECT COUNT(*)::BIGINT INTO v_module_cnt
    FROM public.modules WHERE modules.course_id = p_course_id;

    SELECT COUNT(*)::BIGINT INTO v_lesson_cnt
    FROM public.lessons WHERE lessons.course_id = p_course_id;

    IF v_module_cnt < 1 THEN
        RAISE EXCEPTION 'LTC14: Course must contain at least one module before review.'
            USING ERRCODE = 'LTC14';
    END IF;

    IF v_lesson_cnt < 1 THEN
        RAISE EXCEPTION 'LTC14: Course must contain at least one lesson before review.'
            USING ERRCODE = 'LTC14';
    END IF;

    UPDATE public.courses
    SET status = 'PENDING_REVIEW',
        submitted_at = CURRENT_TIMESTAMP,
        rejection_reason = NULL
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.submitted_at,
        public.courses.rejection_reason
    INTO course_id, title, slug, status, submitted_at, rejection_reason;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC14') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_submit_course_for_review unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while submitting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_publish_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR,
    published_by BIGINT,
    published_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can publish courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    IF v_status NOT IN ('PENDING_REVIEW', 'REJECTED') THEN
        RAISE EXCEPTION 'LTC12: Only pending or rejected courses can be published.'
            USING ERRCODE = 'LTC12';
    END IF;

    UPDATE public.courses
    SET status = 'PUBLISHED',
        published_by = p_admin_id,
        published_at = CURRENT_TIMESTAMP,
        rejection_reason = NULL
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.published_by,
        public.courses.published_at
    INTO course_id, title, slug, status, published_by, published_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_publish_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while publishing the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_reject_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT,
    p_reason    TEXT
)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    rejection_reason TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can reject courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF p_reason IS NULL OR BTRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'LTC13: A rejection reason is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    IF v_status <> 'PENDING_REVIEW' THEN
        RAISE EXCEPTION 'LTC12: Only pending courses can be rejected.'
            USING ERRCODE = 'LTC12';
    END IF;

    UPDATE public.courses
    SET status = 'REJECTED',
        rejection_reason = BTRIM(p_reason)
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.rejection_reason
    INTO course_id, title, slug, status, rejection_reason;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12', 'LTC13') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_reject_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while rejecting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_archive_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can archive courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    UPDATE public.courses
    SET status = 'ARCHIVED'
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status
    INTO course_id, title, slug, status;

    IF course_id IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_archive_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while archiving the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_delete_course(
    p_actor_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id BIGINT,
    title     VARCHAR,
    slug      VARCHAR,
    status    VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_title VARCHAR;
    v_slug  VARCHAR;
    v_status VARCHAR;
BEGIN
    SELECT c.title, c.slug, c.status INTO v_title, v_slug, v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable. Only draft or rejected courses can be deleted.'
            USING ERRCODE = 'LTC12';
    END IF;

    DELETE FROM public.courses WHERE id = p_course_id;

    course_id := p_course_id;
    title     := v_title;
    slug      := v_slug;
    status    := v_status;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


-- =========================================================
-- 9. Module procedures
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_create_module(
    p_actor_id     BIGINT,
    p_course_id    BIGINT,
    p_title        VARCHAR,
    p_description  TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    module_id      BIGINT,
    course_id      BIGINT,
    title          VARCHAR,
    description    TEXT,
    sequence_order INTEGER,
    created_at     TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sequence INTEGER;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Module title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(modules.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.modules
        WHERE modules.course_id = p_course_id;
    END IF;

    INSERT INTO public.modules (course_id, title, description, sequence_order)
    VALUES (p_course_id, BTRIM(p_title), p_description, v_sequence)
    RETURNING
        public.modules.id,
        public.modules.course_id,
        public.modules.title,
        public.modules.description,
        public.modules.sequence_order,
        public.modules.created_at,
        public.modules.updated_at
    INTO module_id, course_id, title, description, sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_update_module(
    p_actor_id      BIGINT,
    p_module_id     BIGINT,
    p_title         VARCHAR,
    p_description   TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    module_id      BIGINT,
    course_id      BIGINT,
    title          VARCHAR,
    description    TEXT,
    sequence_order INTEGER,
    created_at     TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT modules.course_id INTO v_course_id
    FROM public.modules WHERE id = p_module_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Module % does not exist.', p_module_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Module title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(modules.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.modules
        WHERE modules.course_id = v_course_id;
    END IF;

    UPDATE public.modules
    SET title = BTRIM(p_title),
        description = p_description,
        sequence_order = v_sequence
    WHERE id = p_module_id
    RETURNING
        public.modules.id,
        public.modules.course_id,
        public.modules.title,
        public.modules.description,
        public.modules.sequence_order,
        public.modules.created_at,
        public.modules.updated_at
    INTO module_id, course_id, title, description, sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_delete_module(
    p_actor_id  BIGINT,
    p_module_id BIGINT
)
RETURNS TABLE (module_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    SELECT course_id INTO v_course_id
    FROM public.modules WHERE id = p_module_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Module % does not exist.', p_module_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    DELETE FROM public.modules WHERE id = p_module_id;

    module_id := p_module_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


-- =========================================================
-- 10. Lesson procedures
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_create_lesson(
    p_actor_id               BIGINT,
    p_module_id              BIGINT,
    p_title                  VARCHAR,
    p_description            TEXT,
    p_sequence_order         INTEGER,
    p_estimated_duration_minutes INTEGER,
    p_is_preview             BOOLEAN
)
RETURNS TABLE (
    lesson_id                BIGINT,
    module_id                BIGINT,
    course_id                BIGINT,
    title                    VARCHAR,
    description              TEXT,
    sequence_order           INTEGER,
    estimated_duration_minutes INTEGER,
    is_preview               BOOLEAN,
    created_at               TIMESTAMPTZ,
    updated_at               TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT m.course_id INTO v_course_id
    FROM public.modules m WHERE m.id = p_module_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Module % does not exist.', p_module_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Lesson title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lessons.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lessons
        WHERE lessons.module_id = p_module_id;
    END IF;

    INSERT INTO public.lessons (
        course_id,
        module_id,
        title,
        description,
        sequence_order,
        estimated_duration_minutes,
        is_preview
    )
    VALUES (
        v_course_id,
        p_module_id,
        BTRIM(p_title),
        p_description,
        v_sequence,
        GREATEST(COALESCE(p_estimated_duration_minutes, 0), 0),
        COALESCE(p_is_preview, FALSE)
    )
    RETURNING
        public.lessons.id,
        public.lessons.module_id,
        public.lessons.course_id,
        public.lessons.title,
        public.lessons.description,
        public.lessons.sequence_order,
        public.lessons.estimated_duration_minutes,
        public.lessons.is_preview,
        public.lessons.updated_at,
        public.lessons.updated_at
    INTO lesson_id, module_id, course_id, title, description, sequence_order,
         estimated_duration_minutes, is_preview, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_lesson unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the lesson: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_update_lesson(
    p_actor_id               BIGINT,
    p_lesson_id              BIGINT,
    p_title                  VARCHAR,
    p_description            TEXT,
    p_sequence_order         INTEGER,
    p_estimated_duration_minutes INTEGER,
    p_is_preview             BOOLEAN
)
RETURNS TABLE (
    lesson_id                BIGINT,
    module_id                BIGINT,
    course_id                BIGINT,
    title                    VARCHAR,
    description              TEXT,
    sequence_order           INTEGER,
    estimated_duration_minutes INTEGER,
    is_preview               BOOLEAN,
    created_at               TIMESTAMPTZ,
    updated_at               TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_module_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT l.course_id, l.module_id
    INTO v_course_id, v_module_id
    FROM public.lessons l WHERE l.id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Lesson title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lessons.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lessons
        WHERE lessons.module_id = v_module_id;
    END IF;

    UPDATE public.lessons
    SET title = BTRIM(p_title),
        description = p_description,
        sequence_order = v_sequence,
        estimated_duration_minutes = GREATEST(COALESCE(p_estimated_duration_minutes, 0), 0),
        is_preview = COALESCE(p_is_preview, FALSE)
    WHERE id = p_lesson_id
    RETURNING
        public.lessons.id,
        public.lessons.module_id,
        public.lessons.course_id,
        public.lessons.title,
        public.lessons.description,
        public.lessons.sequence_order,
        public.lessons.estimated_duration_minutes,
        public.lessons.is_preview,
        public.lessons.updated_at,
        public.lessons.updated_at
    INTO lesson_id, module_id, course_id, title, description, sequence_order,
         estimated_duration_minutes, is_preview, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_lesson unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the lesson: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_delete_lesson(
    p_actor_id  BIGINT,
    p_lesson_id BIGINT
)
RETURNS TABLE (lesson_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    SELECT course_id INTO v_course_id
    FROM public.lessons WHERE id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    DELETE FROM public.lessons WHERE id = p_lesson_id;

    lesson_id := p_lesson_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_lesson unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the lesson: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


-- =========================================================
-- 11. Lesson content block procedures
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_create_lesson_content_block(
    p_actor_id     BIGINT,
    p_lesson_id    BIGINT,
    p_block_type   VARCHAR,
    p_title        VARCHAR,
    p_body_markdown TEXT,
    p_resource_url TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    block_id      BIGINT,
    lesson_id     BIGINT,
    block_type    VARCHAR,
    title         VARCHAR,
    body_markdown TEXT,
    resource_url  TEXT,
    sequence_order INTEGER,
    created_at    TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT l.course_id INTO v_course_id
    FROM public.lessons l WHERE l.id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_block_type IS NULL OR p_block_type NOT IN ('markdown', 'youtube', 'pdf', 'link', 'image', 'code') THEN
        RAISE EXCEPTION 'LTC13: block_type must be markdown, youtube, pdf, link, image or code.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lesson_content_blocks.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lesson_content_blocks
        WHERE lesson_content_blocks.lesson_id = p_lesson_id;
    END IF;

    INSERT INTO public.lesson_content_blocks (
        lesson_id, block_type, title, body_markdown, resource_url, sequence_order
    )
    VALUES (
        p_lesson_id, p_block_type, p_title, p_body_markdown, p_resource_url, v_sequence
    )
    RETURNING
        public.lesson_content_blocks.id,
        public.lesson_content_blocks.lesson_id,
        public.lesson_content_blocks.block_type,
        public.lesson_content_blocks.title,
        public.lesson_content_blocks.body_markdown,
        public.lesson_content_blocks.resource_url,
        public.lesson_content_blocks.sequence_order,
        public.lesson_content_blocks.created_at,
        public.lesson_content_blocks.updated_at
    INTO block_id, lesson_id, block_type, title, body_markdown, resource_url,
         sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', 'LTC20', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_lesson_content_block unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the content block: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_update_lesson_content_block(
    p_actor_id      BIGINT,
    p_block_id      BIGINT,
    p_title         VARCHAR,
    p_body_markdown TEXT,
    p_resource_url  TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    block_id      BIGINT,
    lesson_id     BIGINT,
    block_type    VARCHAR,
    title         VARCHAR,
    body_markdown TEXT,
    resource_url  TEXT,
    sequence_order INTEGER,
    created_at    TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_lesson_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT l.course_id, cb.lesson_id, cb.block_type
    INTO v_course_id, v_lesson_id, block_type
    FROM public.lesson_content_blocks cb
    JOIN public.lessons l ON l.id = cb.lesson_id
    WHERE cb.id = p_block_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Content block % does not exist.', p_block_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lesson_content_blocks.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lesson_content_blocks
        WHERE lesson_content_blocks.lesson_id = v_lesson_id;
    END IF;

    UPDATE public.lesson_content_blocks
    SET title = p_title,
        body_markdown = p_body_markdown,
        resource_url = p_resource_url,
        sequence_order = v_sequence
    WHERE id = p_block_id
    RETURNING
        public.lesson_content_blocks.id,
        public.lesson_content_blocks.lesson_id,
        public.lesson_content_blocks.block_type,
        public.lesson_content_blocks.title,
        public.lesson_content_blocks.body_markdown,
        public.lesson_content_blocks.resource_url,
        public.lesson_content_blocks.sequence_order,
        public.lesson_content_blocks.created_at,
        public.lesson_content_blocks.updated_at
    INTO block_id, lesson_id, block_type, title, body_markdown, resource_url,
         sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15', 'LTC20', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_lesson_content_block unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the content block: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_delete_lesson_content_block(
    p_actor_id BIGINT,
    p_block_id BIGINT
)
RETURNS TABLE (block_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    SELECT l.course_id INTO v_course_id
    FROM public.lesson_content_blocks cb
    JOIN public.lessons l ON l.id = cb.lesson_id
    WHERE cb.id = p_block_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Content block % does not exist.', p_block_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    DELETE FROM public.lesson_content_blocks WHERE id = p_block_id;

    block_id := p_block_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_lesson_content_block unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the content block: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


-- =========================================================
-- 12. Instructor + admin course listing
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_instructor_courses(p_instructor_id BIGINT)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    category_name    VARCHAR,
    instructor_id    BIGINT,
    instructor_name  TEXT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    module_count     BIGINT,
    lesson_count     BIGINT,
    rejection_reason TEXT,
    submitted_at     TIMESTAMPTZ,
    published_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.id,
        c.title,
        c.slug,
        c.status,
        c.difficulty,
        c.category_id,
        COALESCE(cat.name, 'Uncategorized')::VARCHAR,
        c.instructor_id,
        CONCAT_WS(' ', u.first_name, u.last_name),
        c.short_description,
        c.description,
        c.thumbnail_url,
        (SELECT COUNT(*)::BIGINT FROM public.modules m WHERE m.course_id = c.id),
        (SELECT COUNT(*)::BIGINT FROM public.lessons l WHERE l.course_id = c.id),
        c.rejection_reason,
        c.submitted_at,
        c.published_at,
        c.created_at,
        c.updated_at
    FROM public.courses c
    LEFT JOIN public.categories cat ON cat.id = c.category_id
    LEFT JOIN public.users u ON u.id = c.instructor_id
    WHERE c.instructor_id = p_instructor_id
    ORDER BY c.updated_at DESC, c.id DESC;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_courses(p_status_filter VARCHAR DEFAULT NULL)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    category_name    VARCHAR,
    instructor_id    BIGINT,
    instructor_name  TEXT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    module_count     BIGINT,
    lesson_count     BIGINT,
    rejection_reason TEXT,
    submitted_at     TIMESTAMPTZ,
    published_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.id,
        c.title,
        c.slug,
        c.status,
        c.difficulty,
        c.category_id,
        COALESCE(cat.name, 'Uncategorized')::VARCHAR,
        c.instructor_id,
        CONCAT_WS(' ', u.first_name, u.last_name),
        c.short_description,
        c.description,
        c.thumbnail_url,
        (SELECT COUNT(*)::BIGINT FROM public.modules m WHERE m.course_id = c.id),
        (SELECT COUNT(*)::BIGINT FROM public.lessons l WHERE l.course_id = c.id),
        c.rejection_reason,
        c.submitted_at,
        c.published_at,
        c.created_at,
        c.updated_at
    FROM public.courses c
    LEFT JOIN public.categories cat ON cat.id = c.category_id
    LEFT JOIN public.users u ON u.id = c.instructor_id
    WHERE (p_status_filter IS NULL
           OR BTRIM(p_status_filter) = ''
           OR c.status = UPPER(BTRIM(p_status_filter)))
    ORDER BY
        CASE c.status
            WHEN 'PENDING_REVIEW' THEN 0
            WHEN 'DRAFT' THEN 1
            WHEN 'REJECTED' THEN 2
            ELSE 3
        END ASC,
        c.updated_at DESC,
        c.id DESC;
$$;


-- =========================================================
-- 13. Course indexes
-- =========================================================

CREATE INDEX idx_courses_status
    ON public.courses (status);

CREATE INDEX idx_courses_category_status
    ON public.courses (category_id, status);

CREATE INDEX idx_courses_instructor_status
    ON public.courses (instructor_id, status);

CREATE INDEX idx_courses_difficulty_status
    ON public.courses (difficulty, status);

CREATE INDEX idx_lessons_course
    ON public.lessons (course_id);

CREATE INDEX idx_modules_course
    ON public.modules (course_id);

CREATE INDEX idx_content_blocks_lesson
    ON public.lesson_content_blocks (lesson_id);

-- Autocomplete-friendly trigram search on course titles.
CREATE INDEX idx_courses_title_trgm
    ON public.courses USING GIN (title gin_trgm_ops);

-- Pending-review queue for the admin moderation screen.
CREATE INDEX idx_courses_pending_review
    ON public.courses (status, submitted_at DESC)
    WHERE status = 'PENDING_REVIEW';
