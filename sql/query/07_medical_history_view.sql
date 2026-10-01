
SELECT patient_id,
       visit_id,
       doctor_id,
       diagnosis,
       treatment,
       visit_date
FROM public.medical_history
ORDER BY patient_id, visit_date, visit_id;
