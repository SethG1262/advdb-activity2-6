
SELECT COALESCE(SUM(amount), 0.00) AS total_amount_billed
FROM public.bill;
