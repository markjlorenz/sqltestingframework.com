-- Find four degrees of Kevin Bloom
WITH RECURSIVE kevin_bloom AS (
  SELECT
     actor_id
    ,first_name
    ,last_name
  FROM actor
  WHERE first_name ILIKE 'KEVIN'
    AND last_name ILIKE 'BLOOM'
), film_actor_with_id AS (
  SELECT
     CONCAT(film_actor.actor_id, '-', film_actor.film_id) AS uuid
    ,film_actor.*
  FROM film_actor
), degrees_of_kevin_bloom as (
  SELECT
     0 AS degree
    ,film_actor.film_id
    ,kevin_bloom.actor_id
    ,array[film_actor.uuid] AS path
  FROM kevin_bloom
  JOIN film_actor_with_id AS film_actor
    ON film_actor.actor_id = kevin_bloom.actor_id

  UNION

  SELECT
    degree + 1
    -- For some reason this clause makes the audited version of the query slow
    -- CASE film_actor.actor_id
    --   WHEN dokb.actor_id THEN degree
    --   ELSE degree + 1
    -- END
    ,film_actor.film_id
    ,NULLIF(film_actor.actor_id, dokb.actor_id) AS actor_id
    ,dokb.path || film_actor.uuid AS path
  FROM degrees_of_kevin_bloom AS dokb
  JOIN film_actor_with_id AS film_actor
    ON (
         film_actor.film_id  = dokb.film_id
      OR film_actor.actor_id = dokb.actor_id
    )
   -- AND film_actor.uuid != ANY(dokb.path)
  WHERE degree < 3
), summary AS (
  SELECT
     MIN(degree) AS degree
    ,dokb.actor_id
  FROM degrees_of_kevin_bloom AS dokb
  WHERE dokb.actor_id IS NOT NULL
  GROUP BY dokb.actor_id
)

SELECT
  dokb.degree
  ,actor.first_name
  ,actor.last_name
  ,dokb.path
FROM degrees_of_kevin_bloom AS dokb
JOIN actor
  ON actor.actor_id = dokb.actor_id
;

-- SELECT
--   summary.degree
--   ,actor.first_name
--   ,actor.last_name
-- FROM summary
-- JOIN actor
--   ON actor.actor_id = summary.actor_id
-- ORDER BY degree, actor.first_name, actor.last_name
-- ;
--
-- SELECT
--    MIN(degrees) AS degrees
--   ,COUNT(film_id) AS count_of_films
--   -- film_id
--   ,actor.actor_id
--   ,first_name
--   ,last_name
--   -- ,path
-- FROM degrees_of_kevin_bloom
-- JOIN actor
--   ON actor.actor_id = degrees_of_kevin_bloom.actor_id
-- GROUP BY actor.actor_id, actor.first_name, actor.last_name
-- ORDER BY MIN(degrees), actor_id
-- ;
