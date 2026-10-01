
WITH activity_dates AS (
    SELECT visit_date AS activity_date FROM public.visit
    UNION ALL
    SELECT bill_date FROM public.bill
), months AS (
    SELECT generate_series(
        date_trunc('month', MIN(activity_date)::TIMESTAMP),
        date_trunc('month', MAX(activity_date)::TIMESTAMP),
        INTERVAL '1 month'
    )::DATE AS month_start
    FROM activity_dates
), monthly_visits AS (
    SELECT date_trunc('month', visit_date::TIMESTAMP)::DATE AS month_start,
           COUNT(*) AS total_visits
    FROM public.visit
    GROUP BY 1
), monthly_billing AS (
    SELECT date_trunc('month', bill_date::TIMESTAMP)::DATE AS month_start,
           SUM(amount) AS total_billed
    FROM public.bill
    GROUP BY 1
), monthly_totals AS (
    SELECT m.month_start,
           COALESCE(v.total_visits, 0) AS total_visits,
           COALESCE(b.total_billed, 0.00) AS total_billed
    FROM months AS m
    LEFT JOIN monthly_visits AS v ON v.month_start = m.month_start
    LEFT JOIN monthly_billing AS b ON b.month_start = m.month_start
), monthly_comparison AS (
    SELECT month_start,
           total_visits,
           total_billed,
           LAG(total_visits) OVER (ORDER BY month_start) AS previous_visits,
           LAG(total_billed) OVER (ORDER BY month_start) AS previous_billed
    FROM monthly_totals
)
SELECT to_char(month_start, 'YYYY-MM') AS month,
       total_visits,
       total_billed,
       total_visits - previous_visits AS visits_change,
       ROUND(100.0 * (total_visits - previous_visits)
             / NULLIF(previous_visits, 0), 2) AS visits_change_pct,
       total_billed - previous_billed AS billing_change,
       ROUND(100.0 * (total_billed - previous_billed)
             / NULLIF(previous_billed, 0), 2) AS billing_change_pct
FROM monthly_comparison
ORDER BY month_start;
