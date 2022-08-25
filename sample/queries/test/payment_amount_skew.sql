\set mad_max_tbl payment
\set mad_max_col amount
\set current_date 2006-02-14
:setup_test
WITH text AS (
  SELECT 'Shock Cabin is less than $4.00 per rental' AS value
), expect AS (
  SELECT 0 AS value

), shock_cabin AS (
  SELECT
     rental.rental_id AS rental_id
    ,SUM(payment.amount) AS payment_amounts
  FROM film
  JOIN inventory USING(film_id)
  JOIN rental USING(inventory_id)
  JOIN payment USING(rental_id)
  WHERE film.title ILIKE '%SHOCK CABIN%'
    AND rental_date > :'current_date'::date - 30
  GROUP BY rental.rental_id
), precheck_there_are_two_rentals AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(rental_id) = 2, FALSE)
  FROM shock_cabin
), mad_max AS (
  -- one row with `mad` and `max` columns
  -- `mad` is the median absolute deviation
  -- `max` is 6 mad deviations from the median
  -- anything outside of that is probably an outlier
  :get_mad_max
), precheck_no_skew AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(amount) <= 0, FALSE)
  FROM payment
  FULL JOIN mad_max ON TRUE
  WHERE payment.amount > mad_max.max + mad_max.mad
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM shock_cabin
  WHERE payment_amounts > 4.00
)
:evaluate_test
:cleanup_test

-- \set mad_max_tbl payment
-- \set mad_max_col amount
-- :setup_test
-- WITH text AS (
--   SELECT 'SKEW TEST' AS value
-- ), expect AS (
--   SELECT TRUE AS value
-- ), mad_max AS (
--   -- one row with `mad` and `max` columns
--   -- `mad` is the median absolute deviation
--   -- `max` is 6 mad deviations from the median
--   -- anything outside of that is probably an outlier
--   :get_mad_max
-- ), precheck_no_skew AS (
--   INSERT INTO :"prechecks" (value)
--   SELECT COALESCE(COUNT(amount) <= 0, FALSE)
--   FROM payment
--   FULL JOIN mad_max ON TRUE
--   WHERE payment.amount > mad_max.max + mad_max.mad
-- ), actual AS (
--   SELECT TRUE AS value
-- )
-- :evaluate_test
-- :cleanup_test
