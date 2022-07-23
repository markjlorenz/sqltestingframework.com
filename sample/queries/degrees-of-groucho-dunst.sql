-- Find four degrees of Groucho Dunst
WITH RECURSIVE groucho_dunst AS (
  SELECT
     actor_id
    ,first_name
    ,last_name
  FROM actor
  WHERE first_name ILIKE 'GROUCHO'
    AND last_name ILIKE 'DUNST'
), film_actor_with_id AS (
  SELECT
     gen_random_uuid() AS uuid
    ,film_actor.*
  FROM film_actor
), degrees_of_groucho_dunst as (
  SELECT
     0 AS degrees
    ,film_actor.film_id
    ,groucho_dunst.actor_id
    ,groucho_dunst.first_name
    ,groucho_dunst.last_name
    ,array[film_actor.uuid] AS path
  FROM groucho_dunst
  JOIN film_actor_with_id AS film_actor
    ON film_actor.actor_id = groucho_dunst.actor_id

  UNION ALL

  SELECT
     degrees + 1
    ,film_actor.film_id
    ,actor.actor_id
    ,actor.first_name
    ,actor.last_name
    ,dogd.path || film_actor.uuid AS path
  FROM degrees_of_groucho_dunst as dogd
  JOIN film_actor_with_id AS film_actor
    ON film_actor.film_id = dogd.film_id
   AND film_actor.actor_id != dogd.film_id
   AND NOT film_actor.uuid = ANY(dogd.path)
  JOIN actor
    ON actor.actor_id = film_actor.actor_id
  WHERE degrees < 4
)

SELECT
   degrees
  ,film_id
  ,actor_id
  ,first_name
  ,last_name
FROM degrees_of_groucho_dunst
ORDER BY degrees, film_id, actor_id
;
