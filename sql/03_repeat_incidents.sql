-- Q3. How many incidents are repeats of a problem that was "fixed" a few days earlier,
--     and did the root-cause programme (from Oct 2025) bring that down?
-- A repeat = same asset (site / gateway cluster) + same fault category, opened within 7 days of the previous one.
-- Techniques: CTEs, LAG() within a partition, FILTER, and a ranked "top offenders" list with ROW_NUMBER().

WITH ordered AS (
    SELECT i.*,
           LAG(i.opened_at) OVER (PARTITION BY i.asset_id, i.category ORDER BY i.opened_at) AS prev_opened_at
    FROM incidents i
),
flagged AS (
    SELECT *,
           (prev_opened_at IS NOT NULL AND opened_at - prev_opened_at <= INTERVAL '7 days') AS is_repeat,
           CASE WHEN opened_at < DATE '2025-10-01' THEN '1. Before RCA programme' ELSE '2. After RCA programme' END AS period
    FROM ordered
),
by_period AS (
    SELECT period,
           COUNT(*)                                                    AS incidents,
           COUNT(*) FILTER (WHERE is_repeat)                           AS repeat_incidents,
           ROUND(100.0 * COUNT(*) FILTER (WHERE is_repeat) / COUNT(*), 1) AS repeat_rate_pct
    FROM flagged
    GROUP BY period
),
hotspots AS (
    SELECT f.period, p.project_name || ' / asset ' || f.asset_id AS project_name, f.category,
           COUNT(*) FILTER (WHERE f.is_repeat) AS repeat_incidents,
           ROW_NUMBER() OVER (PARTITION BY f.period ORDER BY COUNT(*) FILTER (WHERE f.is_repeat) DESC) AS rn
    FROM flagged f
    JOIN projects p USING (project_id)
    GROUP BY f.period, p.project_name, f.asset_id, f.category
)
SELECT 'summary' AS section, period, NULL AS project_name, NULL AS category, incidents, repeat_incidents, repeat_rate_pct, NULL::bigint AS hotspot_rank
FROM by_period
UNION ALL
SELECT 'top 5 hotspots', period, project_name, category, NULL, repeat_incidents, NULL, rn
FROM hotspots
WHERE rn <= 5
ORDER BY section, period, hotspot_rank;
