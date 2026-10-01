-- QUERY 1: How many patients visited the clinic last month?
--
-- A patient might have several visits in that month. DISTINCT counts that
-- patient's ID only once; COUNT(*) here would count visits instead of people.
--
-- The visit table supplies the actual visit date. Its appointment supplies the
-- patient_id, so joining the patient table is unnecessary for this count.
-- Scheduled appointments without a visit do not appear in this INNER JOIN.
SELECT
    COUNT(DISTINCT a.patient_id) AS patients_visited_last_month
FROM public.visit AS v
INNER JOIN public.appointment AS a
    ON a.appointment_id = v.appointment_id
WHERE
    -- DATE_TRUNC('month', CURRENT_DATE) gives the start of the current month.
    -- Subtracting one month gives the start of the previous month.
    -- ::DATE converts each boundary to the same date type as visit_date.
    -- >= includes visits on the first day of the previous month.
    v.visit_date >=
        (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::DATE

    -- < excludes the first day of this month and every later date.
    -- This handles different month lengths and the December/January boundary.
    -- Example: running in October 2026 counts September 1 through September 30.
    -- "Last month" means that calendar month, not the preceding 30 days.
    AND v.visit_date < DATE_TRUNC('month', CURRENT_DATE)::DATE;

-- Expected result: exactly one row containing a count, including 0 if no
-- patients have visits in that period. CURRENT_DATE comes from the database
-- session; old mock data may therefore produce a valid count of 0.


-- QUERY 2: Which patients have visited the clinic at least twice?
-- Purpose: identify repeat visitors using GROUP BY and HAVING.
-- Scope: all recorded visits, with no month filter.
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    COUNT(v.visit_id) AS visit_count
FROM public.patient AS p
INNER JOIN public.appointment AS a
    ON a.patient_id = p.patient_id
INNER JOIN public.visit AS v
    ON v.appointment_id = a.appointment_id

-- The joins produce one row per recorded visit. GROUP BY collects the rows
-- for each patient so COUNT can calculate that patient's number of visits.
-- Keep patient_id in the grouping: different people can share the same name.
GROUP BY
    p.patient_id,
    p.first_name,
    p.last_name

-- HAVING filters groups after their visit counts have been calculated.
-- WHERE filters individual input rows before grouping, so a direct condition
-- such as WHERE COUNT(v.visit_id) >= 2 would not work here.
HAVING COUNT(v.visit_id) >= 2

-- Show the most frequent visitors first. The ID makes tied counts predictable.
ORDER BY visit_count DESC, p.patient_id;

-- Expected result: one row per qualifying patient. No rows is a valid result
-- if every patient in the mock data has fewer than two recorded visits.


-- QUERY 3: Which doctors bill more than the average doctor, and what
-- percentage of all clinic billing does each qualifying doctor represent?
--
-- Assumtions of the task:
-- 1. Compare each doctor's TOTAL billed amount, not their average bill size.
-- 2. The average includes every doctor in public.doctor, even with no bills.
-- 3. Use all stored billing dates because this question specifies no period.
-- 4. Include unpaid, partially_paid and paid bills: they are all amounts billed.
-- 5. Each percentage uses ALL clinic billing, including below-average doctors.
--
-- WITH defines named query results (CTEs) for this statement only. To
-- calculate doctor totals first, then calculate the average of those totals.
WITH doctor_totals AS (
    SELECT
        d.doctor_id,
        d.first_name,
        d.last_name,

        -- SUM has no non-NULL amounts for a doctor without bills and returns
        -- NULL. COALESCE replaces that with 0 so the doctor affects the average.
        COALESCE(SUM(b.amount), 0) AS total_billed
    FROM public.doctor AS d

    -- A bill has no doctor_id in this schema. Follow the actual FK path:
    -- doctor -> appointment -> visit -> bill.
    -- LEFT JOIN at every step preserves doctors without appointments or bills.
    LEFT JOIN public.appointment AS a
        ON a.doctor_id = d.doctor_id
    LEFT JOIN public.visit AS v
        ON v.appointment_id = a.appointment_id
    LEFT JOIN public.bill AS b
        ON b.visit_id = v.visit_id

    -- Do not join payment here: a bill can have several payments, which would
    -- repeat its amount and inflate SUM(b.amount). We need the billed amount.
    GROUP BY d.doctor_id, d.first_name, d.last_name
),
clinic_stats AS (
    -- doctor_totals has exactly one row per doctor, including zero-bill doctors.
    -- AVG therefore weights each doctor equally, regardless of bill count.
    -- Calculate the clinic total BEFORE filtering to above-average doctors.
    SELECT
        AVG(total_billed) AS average_doctor_billing,
        SUM(total_billed) AS clinic_total_billing
    FROM doctor_totals
)
SELECT
    dt.doctor_id,
    dt.first_name || ' ' || dt.last_name AS doctor_name,
    ROUND(dt.total_billed, 2) AS doctor_total_billed,
    ROUND(cs.average_doctor_billing, 2) AS average_doctor_billing,
    ROUND(cs.clinic_total_billing, 2) AS clinic_total_billing,

    -- Share (%) = this doctor's total / the whole clinic's total * 100.
    -- NULLIF turns a zero denominator into NULL, preventing division by zero.
    -- ROUND changes the displayed precision to two decimal places.
    ROUND(
        100.0 * dt.total_billed / NULLIF(cs.clinic_total_billing, 0),
        2
    ) AS clinic_billing_share_pct
FROM doctor_totals AS dt

-- clinic_stats contains one row. CROSS JOIN attaches that same average and
-- clinic total to each doctor's row so we can compare and calculate a share.
CROSS JOIN clinic_stats AS cs

-- "More than" means strictly greater: doctors exactly at the average are out.
-- Compare the unrounded values; rounding is only for the displayed columns.
WHERE dt.total_billed > cs.average_doctor_billing
ORDER BY dt.total_billed DESC, dt.doctor_id;

