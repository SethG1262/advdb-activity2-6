WITH totals AS (
    SELECT d.doctor_id, d.first_name, d.last_name,
           p.first_name patient_first, p.last_name patient_last,
           SUM(b.amount) total
    FROM doctor d
    JOIN appointment a ON d.doctor_id = a.doctor_id
    JOIN patient p ON a.patient_id = p.patient_id
    JOIN visit v ON a.appointment_id = v.appointment_id
    JOIN bill b ON v.visit_id = b.visit_id
    GROUP BY d.doctor_id, d.first_name, d.last_name,
             p.patient_id, p.first_name, p.last_name
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY doctor_id ORDER BY total DESC
    ) r
    FROM totals
)
SELECT first_name, last_name, patient_first, patient_last, total
FROM ranked
WHERE r <= 2;
