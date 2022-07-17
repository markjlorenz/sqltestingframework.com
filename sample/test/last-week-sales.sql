WITH text AS (
  SELECT 'Rentals can only have one payment' AS value
), expect AS (
  SELECT 1 AS value
), actual AS (
  SELECT
    COUNT(rental_id) AS value
  FROM payment
  GROUP BY rental_id
  ORDER BY COUNT(rental_id) DESC
  LIMIT 1
)
:evaluate_test ;

WITH text AS (
  SELECT 'Payments can not happen before rentals' AS value
), expect AS (
  SELECT 0 AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM rental
  JOIN payment
    ON payment.rental_id = rental.rental_id
  WHERE payment.payment_date < rental.rental_date
)
:evaluate_test;

WITH text AS (
  SELECT 'Most renters make their last payment within 60 days' AS value
), expect AS (
  SELECT 60 AS value
), payment_periods AS (
  SELECT
    rental.rental_id,
    payment.payment_id,
    payment.payment_date - rental.rental_date AS payment_period
  FROM rental
  JOIN payment
    ON payment.rental_id = rental.rental_id
), actual AS (
  SELECT
    EXTRACT(day FROM AVG(payment_period)) AS value
  FROM payment_periods
)
:evaluate_test;

\set today '\'2005-08-09\'::date'
WITH text AS (
  SELECT 'Rentals can not happen in the future' AS value
), expect AS (
  SELECT 0 AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM rental
  WHERE rental.rental_date > :today
)
:evaluate_test;
\unset today
