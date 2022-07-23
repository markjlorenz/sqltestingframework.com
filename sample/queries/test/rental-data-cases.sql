WITH text AS (
  SELECT 'the rental data is not older than 2005' AS value
), earliest_date AS (
  SELECT
    MIN(rental_date) AS value
  FROM rental
), actual AS (
  SELECT
    EXTRACT(year FROM value) AS value
  FROM earliest_date
), expect AS (
  SELECT 2005 AS value
)
:evaluate_test;

WITH text AS (
  SELECT 'return_date is never earlier than rental_date' AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM rental
  WHERE return_date < rental_date
), expect AS (
  SELECT 0 AS value
)
:evaluate_test;
