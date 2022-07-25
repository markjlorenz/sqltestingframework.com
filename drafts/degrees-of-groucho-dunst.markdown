Goal: Write tests for a query, when the query doesn't write to any tables.

<img src="/images/kevin-bacon-recursive-cte.jpeg" />

## Setup

It's just another Monday at StreamBuster, the buzzy tech startup that's disrupting the streaming video market.  At StreamBuster we believe that there's a billion dollar market for the game-changing convenience that comes from driving to a store, picking up a physical disk (if there's a good one in stock anyway) and driving home with it to enjoy with friends and family.Think of the <em>thrill</em> of the hunt, when a movie you want to watch is in stock.  Think about how much accomplishment you'll feel about having "brought home the bacon" to an adoring spouse and children.  Streaming is dead, people want StreamBuster stores.

Your boss is starting the day late again, it's 1:00PM and she's active 🟢 in Slack for the first time today.  It's bad news when she's starting this late, it usualy means she was out late partying with the sales team- and is bloated with <em>"really good ideas"</em> for you to <em>execute</em> on.  Oh no, here it comes...

> Sandy Holcombs is typing...
> Hey there!  Was out with the sales team last night, and Chad had a brilliant idea to drive more sales.  We're going to re-plan all of the stores, so that at the center of the store are all the movies featuring Groucho Dunst (I love his movies🍿).  Then movies featuring people he's co-stared with will be in the next row out, then people who were featured in movies with people who were featured in movies with Groucho will be in the row after that, and so on.  It will be so easy for customers to find the movie they're looking for once the stores are organzied by Groucho-index.  This is going to be huge.  We've applied for a patent to make sure that those annoying public libraries don't copy it.
>
> I need you to make a list of every actor from every film, and include the Groucho number so that the store managers and staff can work over the holiday weekend to get their stores in shape.
>
> K, thx, bye.

You <em>knew</em> it.  Better get to work.  The last time Holcombs had a genious idea it was more work to talk her out of it than to just do the work.  Anyway, this does sound like a fun assignment (for you anyway- pitty to the poor store managers and their holiday plans). Since the stores can only hold four rows of movies, this will be "four degrees of Groucho Dunst."

<blockquote>instructions for getting the database</blockquote>

## Get to work

The relevent parts of the database at StreamBuster are setup like this:

<pre>
    <code>
postgres=# \d actor
                                        Table "public.actor"
   Column    |            Type             | Nullable |                 Default
-------------+-----------------------------+----------+-----------------------------------------
 actor_id    | integer                     | not null | nextval('actor_actor_id_seq'::regclass)
 first_name  | character varying(45)       | not null |
 last_name   | character varying(45)       | not null |
 last_update | timestamp without time zone | not null | now()

postgres=# \d film_actor
                     Table "public.film_actor"
   Column    |            Type             | Nullable | Default
-------------+-----------------------------+----------+---------
 actor_id    | smallint                    | not null |
 film_id     | smallint                    | not null |
 last_update | timestamp without time zone | not null | now()
postgres=# \d film

                                      Table "public.film"
      Column      |            Type             | Nullable |                Default
------------------+-----------------------------+----------+---------------------------------------
 film_id          | integer                     | not null | nextval('film_film_id_seq'::regclass)
 title            | character varying(255)      | not null |
 description      | text                        |          |
 release_year     | year                        |          |
 length           | smallint                    |          |
 rating           | mpaa_rating                 |          | 'G'::mpaa_rating
 last_update      | timestamp without time zone | not null | now()
    </code>
</pre>

We can figure this out using the <code>actor</code> and <code>film_actor</code> tables, then just join-in the <code>film</code> table so that the store managers know the film title, but it's going to be a complex query, and require use to use a <code>RECURSIVE</code> common table expression (CTE)- which we will certainly get wrong at first and will be very hard to know if we're right.  Sql Testing Framework will help us here!

In picture form, we're looking to get a result that looks something like this:
<img src="/images/degrees-epplanation.png" />

## A monster query

After several hours, you come up with this monster of a query:

<pre>
    <code>
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
    </code>
</pre>

Because this query is a pure function, without side effects, the testing techniques we used in the first tutorial won't work here. We'll need to use a few more features of Sql Testing Framework.  Our new tests are going to follow this form:

<pre>
    <code>
\set query /queries/degrees-of-kevin-bloom.sql
:setup_test
WITH text AS (
  SELECT 'Some assertion about the query result' AS value
), expect AS (
  -- SELECT something_we_expect AS value
), actual AS (
  -- SELECT something AS value
  -- FROM "/queries/degress-of-kevin-bloom.sql"
)
:evaluate_test
:cleanup_test
    </code>
</pre>

Let's break it down:
<ul>
    <li><code>\set query /queries/degrees-of-kevin-bloom.sql</code>
        <p>With this line we are telling Sql Testing Framework the name of the file that contains our query-under-test.</p>
    </li>
    <li><pre><code>
:setup_test
WITH text AS (
  SELECT 'Some assertion about the query result' AS value
), expect AS (
  -- SELECT something_we_expect AS value
)
        </code></pre>
        <p>This next part is exactly the same as first tutorial, <a href="/writing-sql-tests.html">Writing SQL Tests</a></p>
    </li>
    <li><pre><code>
), actual AS (
  -- SELECT something AS value
  -- FROM "/queries/degress-of-kevin-bloom.sql"
)
        </code></pre>
        <p>SQL Testing Framework will automatically create an ephemeral table for us that stores the rest (while the tests are running).  The table has the same name as the filename of the query-under-test, so we can reference it in <code>FROM "/queries/degress-of-kevin-bloom.sql"</code>.</p>
    </li>
    <li><pre><code>
:evaluate_test
:cleanup_test
        </code></pre>
        <p>Finally, tell Sql Testing Framework to run the tests and clean up the ephemeral table and variables.</p>
    </li>
</ul>

## Writing the tests

Let's start by verify a few records to make sure that the query is right at least some of the time.

<pre>
    <code>
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
    </code>
<pre>

This gives us a good feeling about the first-order connections:

<pre>
    <code>
Expect:
{2,5,8,9,10,12,14,16,17,19,20,21,22,23,26,29,32,35,36,37,38,39,41,44,46,48,50,51,53,56,57,58,60,62,66,68,69,73,76,77,78,80,81,87,89,92,94,95,97,100,102,104,105,106,107,111,112,114,115,116,118,119,123,125,126,127,128,132,136,137,138,142,143,146,147,148,149,150,152,155,160,165,166,169,172,173,177,178,181,183,185,187,188,190,191,192,194,198,200}

Actual:
{2,5,8,9,10,12,14,16,17,19,20,21,22,23,26,29,32,35,36,37,38,39,41,44,46,48,50,51,53,56,57,58,60,62,66,68,69,73,76,77,78,80,81,87,89,92,94,95,97,100,102,104,105,106,107,111,112,114,115,116,118,119,123,125,126,127,128,132,136,137,138,142,143,146,147,148,149,150,152,155,160,165,166,169,172,173,177,178,181,183,185,187,188,190,191,192,194,198,200}

Did Pass: t
Text: The first order actors are correct
    </code>
<pre>

Second-order connections are anyone who was in a movie with a first-order connection (assuming they themselves are not a first order connection).  Verifying the second-order actors is just another iteration of the first order test:

<pre>
    <code>
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
-- NEW STUFF STARTS HERE --
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
    </code>
<pre>

<pre>
    <code>
Expect:
{1,3,4,6,7,11,13,15,18,24,27,28,30,31,33,34,40,42,43,45,47,49,52,54,55,59,61,63,64,65,67,70,71,72,74,75,79,82,83,84,85,86,88,90,91,93,96,98,99,101,103,108,109,110,113,117,120,121,122,124,129,130,131,133,134,135,139,140,141,144,145,151,153,154,156,157,158,159,161,162,163,164,167,168,170,171,174,175,176,179,180,182,184,186,189,193,195,196,197,199}

Actual:
{1,3,4,6,7,11,13,15,18,24,27,28,30,31,33,34,40,42,43,45,47,49,52,54,55,59,61,63,64,65,67,70,71,72,74,75,79,82,83,84,85,86,88,90,91,93,96,98,99,101,103,108,109,110,113,117,120,121,122,124,129,130,131,133,134,135,139,140,141,144,145,151,153,154,156,157,158,159,161,162,163,164,167,168,170,171,174,175,176,179,180,182,184,186,189,193,195,196,197,199}

Did Pass: t
Text: The second order actors are correct
    </code>
<pre>

CLOSE IT OUT
