-- Q9. One vendor scorecard for the last two quarters of data (2026 H1), combining operations and finance.
-- Techniques: several CTEs joined together, PERCENT_RANK() to put different metrics on one 0-1 scale,
-- and DENSE_RANK() on the combined score.

WITH params AS (
    SELECT TIMESTAMP '2026-01-01' AS from_ts, TIMESTAMP '2026-07-01' AS to_ts
),
ops AS (
    SELECT i.vendor_id,
           COUNT(*)                                                                                 AS incidents,
           AVG((i.resolved_at <= i.opened_at + make_interval(hours => s.resolution_target_hrs))::int) AS resolution_sla,
           AVG((i.responded_at <= i.opened_at + make_interval(mins => s.response_target_min))::int)   AS response_sla
    FROM incidents i
    JOIN sla_policy s USING (priority)
    CROSS JOIN params p
    WHERE i.opened_at >= p.from_ts AND i.opened_at < p.to_ts AND i.resolved_at IS NOT NULL
    GROUP BY i.vendor_id
),
lagged AS (
    SELECT vendor_id, opened_at,
           LAG(opened_at) OVER (PARTITION BY asset_id, category ORDER BY opened_at) AS prev_opened_at
    FROM incidents
),
repeat_rate AS (
    SELECT l.vendor_id,
           AVG(COALESCE(l.opened_at - l.prev_opened_at <= INTERVAL '7 days', FALSE)::int) AS repeat_rate   -- share of all incidents that are repeats
    FROM lagged l
    CROSS JOIN params p
    WHERE l.opened_at >= p.from_ts AND l.opened_at < p.to_ts
    GROUP BY l.vendor_id
),
scored AS (
    SELECT o.vendor_id, o.incidents, o.resolution_sla, o.response_sla, r.repeat_rate,
           PERCENT_RANK() OVER (ORDER BY o.resolution_sla)        AS s_resolution,
           PERCENT_RANK() OVER (ORDER BY o.response_sla)          AS s_response,
           PERCENT_RANK() OVER (ORDER BY r.repeat_rate DESC)      AS s_repeat      -- fewer repeats = better
    FROM ops o
    JOIN repeat_rate r USING (vendor_id)
    WHERE o.incidents >= 50
)
SELECT DENSE_RANK() OVER (ORDER BY 0.5 * s_resolution + 0.3 * s_response + 0.2 * s_repeat DESC) AS overall_rank,
       v.vendor_name,
       v.contract_tier,
       incidents,
       ROUND(100 * resolution_sla, 1)                                   AS resolution_sla_pct,
       ROUND(100 * response_sla, 1)                                     AS response_sla_pct,
       ROUND(100 * repeat_rate, 1)                                      AS repeat_rate_pct,
       ROUND((0.5 * s_resolution + 0.3 * s_response + 0.2 * s_repeat)::numeric, 2) AS score_0_to_1
FROM scored
JOIN vendors v USING (vendor_id)
ORDER BY overall_rank;
