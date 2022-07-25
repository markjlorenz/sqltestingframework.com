\set query /queries/degrees-of-kevin-bloom.sql
:setup_test
WITH text AS (
  SELECT 'The first order actors are correct' AS value
), kevin_bloom AS (
  SELECT
     actor_id
  FROM actor
  WHERE first_name ILIKE 'KEVIN'
    AND last_name ILIKE 'BLOOM'
), kevin_bloom_films AS (
  SELECT
    film_actor.film_id
  FROM film_actor
  JOIN kevin_bloom
    ON kevin_bloom.actor_id = film_actor.actor_id
), first_order_actors AS (
  SELECT DISTINCT ON (film_actor.actor_id)
    film_actor.film_id
    ,film_actor.actor_id
    ,actor.first_name
    ,actor.last_name
  FROM film_actor
  JOIN kevin_bloom_films
    ON kevin_bloom_films.film_id = film_actor.film_id
  JOIN actor
    ON actor.actor_id = film_actor.actor_id
  LEFT OUTER JOIN kevin_bloom -- need to remove Kevin himself.
    ON kevin_bloom.actor_id = film_actor.actor_id
  WHERE kevin_bloom.actor_id IS NULL
  ORDER BY film_actor.actor_id
), expect AS (
  SELECT
    -- bunch up all the actor_ids for comparison
    ARRAY_AGG(actor_id::integer ORDER BY actor_id) AS value
  FROM first_order_actors
), actual AS (
  SELECT
    ARRAY_AGG(actor_id::integer ORDER BY actor_id) AS value
  FROM "/queries/degrees-of-kevin-bloom.sql"
  WHERE degree = 1
)
:evaluate_test
:cleanup_test

\set query /queries/degrees-of-kevin-bloom.sql
:setup_test
WITH text AS (
  SELECT 'The second order actors are correct' AS value
), kevin_bloom AS (
  SELECT
     actor_id
  FROM actor
  WHERE first_name ILIKE 'KEVIN'
    AND last_name ILIKE 'BLOOM'
), kevin_bloom_films AS (
  SELECT
    film_actor.film_id
  FROM film_actor
  JOIN kevin_bloom
    ON kevin_bloom.actor_id = film_actor.actor_id
), first_order_actors AS (
  SELECT DISTINCT ON (film_actor.actor_id)
    film_actor.film_id
    ,film_actor.actor_id
    ,actor.first_name
    ,actor.last_name
  FROM film_actor
  JOIN kevin_bloom_films
    ON kevin_bloom_films.film_id = film_actor.film_id
  JOIN actor
    ON actor.actor_id = film_actor.actor_id
  LEFT OUTER JOIN kevin_bloom -- need to remove Kevin himself.
    ON kevin_bloom.actor_id = film_actor.actor_id
  WHERE kevin_bloom.actor_id IS NULL
  ORDER BY film_actor.actor_id
), first_order_films AS (
  SELECT
    film_actor.film_id
  FROM film_actor
  JOIN first_order_actors
    ON first_order_actors.actor_id = film_actor.actor_id
), second_order_actors AS (
  SELECT DISTINCT ON (film_actor.actor_id)
    film_actor.film_id
    ,film_actor.actor_id
    ,actor.first_name
    ,actor.last_name
  FROM film_actor
  JOIN first_order_films
    ON first_order_films.film_id = film_actor.film_id
  JOIN actor
    ON actor.actor_id = film_actor.actor_id
  LEFT OUTER JOIN kevin_bloom -- need to remove Kevin himself.
    ON kevin_bloom.actor_id = film_actor.actor_id
  LEFT OUTER JOIN first_order_actors -- need to remove first-order actors
    ON first_order_actors.actor_id = film_actor.actor_id
  WHERE kevin_bloom.actor_id IS NULL
    AND first_order_actors.actor_id IS NULL
  ORDER BY film_actor.actor_id
), expect AS (
  SELECT
    -- bunch up all the actor_ids for comparison
    ARRAY_AGG(actor_id::integer ORDER BY actor_id) AS value
  FROM second_order_actors
), actual AS (
  SELECT
    ARRAY_AGG(actor_id::integer ORDER BY actor_id) AS value
  FROM "/queries/degrees-of-kevin-bloom.sql"
  WHERE degree = 2
)
:evaluate_test
:cleanup_test
