-- Q5. What does "normal" resolution time look like per priority (median, P90),
--     and which vendors produce most of the extreme outliers?
-- Techniques: PERCENTILE_CONT (ordered-set aggregate), PERCENT_RANK() window, CTE chain.

WITH resolved AS (
    SELECT i.incident_id, i.vendor_id, i.priority,
           EXTRACT(EPOCH FROM (i.resolved_at - i.opened_at)) / 3600.0 AS hours
    FROM incidents i
    WHERE i.resolved_at IS NOT NULL
),
benchmarks AS (
    SELECT priority,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours)::numeric, 1) AS median_hours,
           ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) AS p90_hours
    FROM resolved
    GROUP BY priority
),
scored AS (
    SELECT r.*,
           PERCENT_RANK() OVER (PARTITION BY r.priority ORDER BY r.hours) AS pct_rank
    FROM resolved r
),
outliers AS (           -- slowest 5% within each priority
    SELECT vendor_id, COUNT(*) AS outlier_incidents
    FROM scored
    WHERE pct_rank >= 0.95
    GROUP BY vendor_id
)
SELECT v.vendor_name,
       o.outlier_incidents,
       ROUND(100.0 * o.outlier_incidents / SUM(o.outlier_incidents) OVER (), 1)               AS share_of_all_outliers_pct,
       ROUND(100.0 * SUM(o.outlier_incidents) OVER (ORDER BY o.outlier_incidents DESC, v.vendor_name)
                   / SUM(o.outlier_incidents) OVER (), 1)                                      AS cumulative_share_pct,
       (SELECT string_agg(priority || ': median ' || median_hours || 'h / P90 ' || p90_hours || 'h', ' | ' ORDER BY priority)
          FROM benchmarks)                                                                     AS benchmarks
FROM outliers o
JOIN vendors v USING (vendor_id)
ORDER BY o.outlier_incidents DESC
LIMIT 10;
