-- \include '/queries/utils/percent.sql'
-- \set film_name 'Agent Truman'
WITH film_by_staff AS (
  SELECT
     COUNT(film.title) AS staff_rental
    ,staff.first_name
    ,staff.last_name
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
  JOIN staff USING(staff_id)
  WHERE film.title = :'film_name'
  GROUP BY staff_id
), film_total AS (
  SELECT
    COUNT(*) AS total_rental
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
  WHERE film.title = :'film_name'
), summary AS (
  SELECT
    *
  FROM film_by_staff
  FULL JOIN film_total ON TRUE
)

SELECT
   first_name
  ,last_name
  ,staff_rental
  ,total_rental
  ,PERCENT(staff_rental, total_rental) AS pct_of_rental
FROM summary
