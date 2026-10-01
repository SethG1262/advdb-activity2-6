-- Medical clinic views. Run after schema.sql and before verify.sql.
-- Connect to sait_medical_clinic. The view is created in public.

BEGIN;

-- A normal view reads the current rows: new/updated visits appear on the next query.
-- No duplicated medical-history table and no doctor_id stored on visit or bill.
CREATE OR REPLACE VIEW public.medical_history AS
SELECT
    a.patient_id,
    v.visit_id,
    a.doctor_id,
    v.diagnosis,
    v.treatment,
    v.visit_date
FROM public.visit AS v
JOIN public.appointment AS a ON a.appointment_id = v.appointment_id;

COMMENT ON VIEW public.medical_history IS
    'Patient medical history derived from visits and appointments; includes doctor_id.';

COMMIT;
