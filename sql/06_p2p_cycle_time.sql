-- Q6. How long does procure-to-pay take, stage by stage, and did the July 2025 process redesign help?
-- Techniques: CTEs, PERCENTILE_CONT medians, AVG() OVER a 3-month frame, conditional aggregation.

WITH po_invoice AS (
    SELECT po.po_id,
           date_trunc('month', po.created_at)::date                         AS month,
           EXTRACT(EPOCH FROM (po.approved_at - po.created_at)) / 86400.0  AS po_approval_days,
           inv.approved_date - inv.received_date                            AS invoice_approval_days,
           inv.paid_date,
           inv.due_date
    FROM purchase_orders po
    JOIN invoices inv USING (po_id)
    WHERE po.status <> 'Cancelled'
),
monthly AS (
    SELECT month,
           COUNT(DISTINCT po_id)                                                                 AS pos,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY po_approval_days)::numeric, 1)      AS median_po_approval_days,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY invoice_approval_days)::numeric, 1) AS median_invoice_approval_days,
           ROUND(100.0 * COUNT(*) FILTER (WHERE paid_date <= due_date)
                       / NULLIF(COUNT(*) FILTER (WHERE paid_date IS NOT NULL), 0), 1)            AS paid_on_time_pct
    FROM po_invoice
    GROUP BY month
)
SELECT month,
       CASE WHEN month < DATE '2025-07-01' THEN 'Before redesign' ELSE 'After redesign' END AS period,
       pos,
       median_po_approval_days,
       ROUND(AVG(median_po_approval_days) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS rolling_3m_po_approval_days,
       median_invoice_approval_days,
       paid_on_time_pct
FROM monthly
ORDER BY month;
