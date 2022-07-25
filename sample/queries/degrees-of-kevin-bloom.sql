-- Find four degrees of Kevin Bloom
--
WITH RECURSIVE kevin_bloom AS (
  SELECT
     actor_id
    ,first_name
    ,last_name
  FROM actor
  WHERE first_name ILIKE 'KEVIN'
    AND last_name ILIKE 'BLOOM'
), degrees_of_kevin_bloom as (
  SELECT
     0 AS degree
    ,film_actor.film_id
    ,kevin_bloom.actor_id
  FROM kevin_bloom
  JOIN film_actor
    ON film_actor.actor_id = kevin_bloom.actor_id

  UNION

  SELECT
    CASE film_actor.actor_id
      WHEN dokb.actor_id THEN degree
      ELSE degree + 1
    END
    ,film_actor.film_id
    ,NULLIF(film_actor.actor_id, dokb.actor_id) AS actor_id
  FROM degrees_of_kevin_bloom AS dokb
  JOIN film_actor
    ON (
         film_actor.film_id  = dokb.film_id
      OR film_actor.actor_id = dokb.actor_id
    )
  WHERE degree < 4
), summary AS (
  SELECT
     MIN(degree) AS degree
    ,dokb.actor_id
  FROM degrees_of_kevin_bloom AS dokb
  WHERE dokb.actor_id IS NOT NULL
  GROUP BY dokb.actor_id
)

SELECT
  summary.degree
  ,actor.first_name
  ,actor.last_name
  ,actor.actor_id
FROM summary
JOIN actor
  ON actor.actor_id = summary.actor_id
ORDER BY degree, actor.first_name, actor.last_name
;
