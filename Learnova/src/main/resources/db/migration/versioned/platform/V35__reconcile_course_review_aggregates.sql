-- Course-card ratings must always represent real rows in public.reviews.
-- Earlier demo seeds populated display counters directly; reconcile those
-- denormalized fields once so catalogue, dashboard, and detail cards start
-- from the same source of truth as the review read model.
UPDATE public.courses c
SET
    avg_rating = COALESCE((
        SELECT ROUND(AVG(r.rating), 2)
        FROM public.reviews r
        WHERE r.course_id = c.id
    ), 0.00),
    review_count = (
        SELECT COUNT(*)
        FROM public.reviews r
        WHERE r.course_id = c.id
    );
