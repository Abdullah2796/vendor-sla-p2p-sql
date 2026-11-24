-- Q8. For each vendor, what is the longest run of consecutive months meeting the 95% resolution SLA target?
-- Classic "gaps and islands": the month index minus ROW_NUMBER() is constant within a streak.
-- Techniques: CTEs, ROW_NUMBER(), DENSE_RANK(), grouping on a derived island key.

WITH monthly AS (
    SELECT i.vendor_id,
           date_trunc('month', i.opened_at)::date AS month,
           AVG((i.resolved_at <= i.opened_at + make_interval(hours => s.resolution_target_hrs))::int) AS sla_rate
    FROM incidents i
    JOIN sla_policy s USING (priority)
    WHERE i.resolved_at IS NOT NULL
    GROUP BY i.vendor_id, date_trunc('month', i.opened_at)
),
hits AS (
    SELECT vendor_id, month,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_idx
    FROM monthly
    WHERE sla_rate >= 0.95
),
islands AS (
    SELECT vendor_id, month,
           month_idx - ROW_NUMBER() OVER (PARTITION BY vendor_id ORDER BY month) AS island_key
    FROM hits
),
streaks AS (
    SELECT vendor_id,
           MIN(month) AS streak_start,
           MAX(month) AS streak_end,
           COUNT(*)   AS months_in_a_row
    FROM islands
    GROUP BY vendor_id, island_key
),
best AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY vendor_id ORDER BY months_in_a_row DESC, streak_end DESC) AS rn
    FROM streaks s
)
SELECT DENSE_RANK() OVER (ORDER BY b.months_in_a_row DESC) AS rank,
       v.vendor_name,
       b.months_in_a_row,
       b.streak_start,
       b.streak_end
FROM best b
JOIN vendors v USING (vendor_id)
WHERE b.rn = 1
ORDER BY rank, v.vendor_name;
