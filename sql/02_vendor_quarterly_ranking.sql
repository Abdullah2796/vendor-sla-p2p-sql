-- Q2. Which vendors are best and worst each quarter, and who is moving up or down?
-- Techniques: CTEs, RANK(), NTILE() quartiles, LAG() on the rank to show movement.

WITH resolved AS (
    SELECT i.vendor_id,
           to_char(i.opened_at, 'YYYY-"Q"Q')                                                AS quarter,
           EXTRACT(EPOCH FROM (i.resolved_at - i.opened_at)) / 3600.0                       AS hours_to_resolve,
           (i.resolved_at <= i.opened_at + make_interval(hours => s.resolution_target_hrs)) AS met
    FROM incidents i
    JOIN sla_policy s USING (priority)
    WHERE i.resolved_at IS NOT NULL
),
vendor_quarter AS (
    SELECT vendor_id, quarter,
           COUNT(*)                                   AS incidents,
           ROUND(100.0 * AVG(met::int), 1)            AS resolution_sla_pct,
           ROUND(AVG(hours_to_resolve)::numeric, 1)   AS avg_hours_to_resolve
    FROM resolved
    GROUP BY vendor_id, quarter
    HAVING COUNT(*) >= 30                              -- ignore vendors with too few tickets to rank fairly
),
ranked AS (
    SELECT vq.*,
           RANK()  OVER (PARTITION BY quarter ORDER BY resolution_sla_pct DESC, avg_hours_to_resolve) AS sla_rank,
           NTILE(4) OVER (PARTITION BY quarter ORDER BY resolution_sla_pct DESC)                     AS quartile
    FROM vendor_quarter vq
)
SELECT r.quarter,
       v.vendor_name,
       v.category,
       r.incidents,
       r.resolution_sla_pct,
       r.avg_hours_to_resolve,
       r.sla_rank,
       LAG(r.sla_rank) OVER (PARTITION BY r.vendor_id ORDER BY r.quarter) - r.sla_rank AS places_moved_up,
       CASE r.quartile WHEN 1 THEN 'Top 25%' WHEN 4 THEN 'Bottom 25% - review' ELSE 'Middle' END AS performance_band
FROM ranked r
JOIN vendors v USING (vendor_id)
ORDER BY r.quarter, r.sla_rank;
