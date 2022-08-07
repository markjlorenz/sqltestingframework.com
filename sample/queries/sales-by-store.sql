SELECT
   store.store_id
  ,DATE_PART('month', payment_date) AS payment_month
  ,SUM(payment.amount) AS total_payment
FROM store
JOIN staff USING(store_id)
JOIN payment USING(staff_id)
GROUP BY store_id, DATE_PART('month', payment_date)
;
