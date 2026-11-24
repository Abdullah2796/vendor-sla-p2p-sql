-- Q4. How big was the open incident backlog at the end of each day, and what was the worst week?
-- Techniques: UNION ALL of open/close events, running SUM() OVER (ORDER BY ...), then MAX() OVER a 7-day frame.

WITH events AS (
    SELECT opened_at::date AS day, 1 AS delta FROM incidents
    UNION ALL
    SELECT resolved_at::date, -1 FROM incidents WHERE resolved_at IS NOT NULL
),
daily AS (
    SELECT day, SUM(delta) AS net_change
    FROM events
    GROUP BY day
),
backlog AS (
    SELECT day,
           net_change,
           SUM(net_change) OVER (ORDER BY day ROWS UNBOUNDED PRECEDING) AS open_backlog
    FROM daily
)
SELECT day,
       net_change,
       open_backlog,
       MAX(open_backlog) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS peak_last_7_days,
       ROUND(AVG(open_backlog) OVER (ORDER BY day ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 1) AS avg_last_30_days
FROM backlog
ORDER BY day;
