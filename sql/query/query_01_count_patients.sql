-- Query 1: Count the total number of patients in the database.
-- Run while connected to sait_medical_clinic.

SELECT COUNT(*) AS total_patients
FROM public.patient;
