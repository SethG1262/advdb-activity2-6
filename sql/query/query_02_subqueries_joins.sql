-- Query 2: One query that uses subqueries and JOINs.
-- Lists patients who have at least one completed appointment, with their
-- appointment count, total billed amount and total paid amount.
-- Run while connected to sait_medical_clinic.

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    COUNT(DISTINCT a.appointment_id)  AS total_appointments,
    COALESCE(SUM(b.amount), 0)        AS total_billed,
    COALESCE(SUM(pay.paid), 0)        AS total_paid
FROM public.patient p
LEFT JOIN public.appointment a
       ON a.patient_id = p.patient_id
LEFT JOIN public.visit v
       ON v.appointment_id = a.appointment_id
LEFT JOIN public.bill b
       ON b.visit_id = v.visit_id
LEFT JOIN (
        -- Subquery in FROM: total payments per bill
        SELECT bill_id, SUM(amount_paid) AS paid
        FROM public.payment
        GROUP BY bill_id
     ) pay
       ON pay.bill_id = b.bill_id
WHERE p.patient_id IN (
        -- Subquery in WHERE: patients with a completed appointment
        SELECT patient_id
        FROM public.appointment
        WHERE status = 'completed'
     )
GROUP BY p.patient_id, p.first_name, p.last_name
ORDER BY total_billed DESC;
