-- Q1. How is each vendor's SLA compliance moving month to month?
-- Techniques: CTEs, AVG() OVER with a ROWS frame (rolling 3 months), LAG() for month-over-month change.

WITH incident_sla AS (
    SELECT i.vendor_id,
           date_trunc('month', i.opened_at)::date                                         AS month,
           (i.responded_at <= i.opened_at + make_interval(mins  => s.response_target_min))  AS response_met,
           (i.resolved_at  <= i.opened_at + make_interval(hours => s.resolution_target_hrs)) AS resolution_met
    FROM incidents i
    JOIN sla_policy s USING (priority)
    WHERE i.resolved_at IS NOT NULL
),
vendor_month AS (
    SELECT vendor_id, month,
           COUNT(*)                                                   AS incidents,
           ROUND(100.0 * AVG(response_met::int), 1)                   AS response_sla_pct,
           ROUND(100.0 * AVG(resolution_met::int), 1)                 AS resolution_sla_pct
    FROM incident_sla
    GROUP BY vendor_id, month
)
SELECT v.vendor_name,
       vm.month,
       vm.incidents,
       vm.resolution_sla_pct,
       ROUND(AVG(vm.resolution_sla_pct) OVER w3, 1)                              AS rolling_3m_resolution_pct,
       vm.resolution_sla_pct - LAG(vm.resolution_sla_pct) OVER (PARTITION BY vm.vendor_id ORDER BY vm.month) AS mom_change_pts,
       vm.response_sla_pct
FROM vendor_month vm
JOIN vendors v USING (vendor_id)
WINDOW w3 AS (PARTITION BY vm.vendor_id ORDER BY vm.month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
ORDER BY v.vendor_name, vm.month;
