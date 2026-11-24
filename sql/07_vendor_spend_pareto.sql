-- Q7. Which vendors make up most of our spend? (Pareto / ABC classification)
-- Techniques: SUM() OVER () for the grand total, running SUM() OVER (ORDER BY ...) for cumulative share, RANK().

WITH spend AS (
    SELECT po.vendor_id, SUM(inv.invoice_amount) AS invoiced
    FROM invoices inv
    JOIN purchase_orders po USING (po_id)
    GROUP BY po.vendor_id
),
pareto AS (
    SELECT vendor_id,
           invoiced,
           RANK() OVER (ORDER BY invoiced DESC)                                             AS spend_rank,
           100.0 * invoiced / SUM(invoiced) OVER ()                                          AS share_pct,
           100.0 * SUM(invoiced) OVER (ORDER BY invoiced DESC ROWS UNBOUNDED PRECEDING)
                 / SUM(invoiced) OVER ()                                                     AS cumulative_pct
    FROM spend
)
SELECT p.spend_rank,
       v.vendor_name,
       v.category,
       ROUND(p.invoiced, 0)        AS invoiced_eur,
       ROUND(p.share_pct, 1)       AS share_pct,
       ROUND(p.cumulative_pct, 1)  AS cumulative_pct,
       CASE WHEN p.cumulative_pct - p.share_pct < 80 THEN 'A'      -- vendors that take us up to 80% of spend
            WHEN p.cumulative_pct - p.share_pct < 95 THEN 'B'
            ELSE 'C' END            AS abc_class
FROM pareto p
JOIN vendors v USING (vendor_id)
ORDER BY p.spend_rank;
