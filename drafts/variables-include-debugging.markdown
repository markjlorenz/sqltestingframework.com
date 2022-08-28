# Variables, Include, and Debugging

Goal: Leverage \include and \set to write more modular queries, and be able to debug them.

It's Saturday evening, and you're enjoying the Aurora Borealis from your living room when you see a Slack message from Sandy Holcombs, VP of Sales:

> Sandy Holcombs is typing...
> 👋 HI HI HI👋 On Friday morning the CEO asked me what the percent of rentals for his favorite films were handled by each sales associate.  I need this from you now, and it better be right. OK? Thank you, you're the best!!

Oh well, 🤦.  I'm sure the aurora will still be there when you finish this request for Holcombs.  Like everything you've been asked for (except <a href="https://www.sqltestingframework.com/testing-sql-query-results.html">that recursive Kevin Bloom thing</a>), this should be simple enough.

## Get started

What a moment, Holcombs didn't say which films were the CEOs favorites, and she's 🔴 in Slack now.  That's OK we can handle that with a variable.

<pre><code><span class="highlight">\include '/queries/utils/percent.sql'</span>
<span class="highlight">\set film_name 'Agent Truman'</span>
WITH film_by_staff AS (
  SELECT
     COUNT(film.title) AS staff_rental
    ,staff.first_name
    ,staff.last_name
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
  JOIN staff USING(staff_id)
<span class="highlight">  WHERE film.title = :'film_name'</span>
  GROUP BY staff_id
), film_total AS (
  SELECT
    COUNT(*) AS total_rental
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
<span class="highlight">  WHERE film.title = :'film_name'</span>
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
FROM summary</code></pre>

This query makes use of two great PSQL features, <code>\include</code> and <code>\set</code>.

<code>\include</code> let's us include other files as if they'd been written here. SQL Testing Framework includes some utilities, like a <code>PERCENTAGE</code> function in <code>queries/utils</code> that are mean to be used by <code>\include</code>.

<code>\set</code> defines a variable, that's used later by with a <code>:</code>.  In this case <code>:'film_name'</code>, which will let us put in a placeholder until Holcombs can tell us what the CEO's favorite films are.

This looks good, let's test it:

<pre><code>\set query '/queries/variables_include_debugging.sql'
:setup_test
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/variables_include_debugging.sql"
)
:evaluate_test
:cleanup_test</code></pre>

Let's run the test:

<pre><code>./runner.sh variables_include_debugging.sql
 ●psql:variables_include_debugging.sql:4: ERROR:  syntax error at or near "CREATE"
LINE 4:         CREATE TEMP TABLE "prechecks" (value BOOLEAN)
                ^
</code></pre>

Hmm, an error.  How can we figure out what the problem is?  SQL Testing Framework exposes and environment variable that can help debug errors.  We can define <code>STF_ECHO='queries'</code> to print the output of our test queries, which will help figure out what's wrong.

<pre><code>export STF_ECHO='queries'; ./runner.sh variables_include_debugging.sql
 ●CREATE OR REPLACE FUNCTION PERCENT(numerator anycompatible, denominator anycompatible)
RETURNS numeric LANGUAGE plpgsql AS $$
BEGIN
    RETURN ROUND(numerator::numeric / denominator::numeric * 100, 2);
END $$;
BEGIN;
CREATE OR REPLACE FUNCTION PERCENT(numerator anycompatible, denominator anycompatible)
RETURNS numeric LANGUAGE plpgsql AS $$
BEGIN
    RETURN ROUND(numerator::numeric / denominator::numeric * 100, 2);
END $$;
CREATE TEMP TABLE "/queries/variables_include_debugging.sql"
            ON COMMIT DROP
<span class="highlight">            AS</span>
<span class="highlight">        CREATE TEMP TABLE "prechecks" (value BOOLEAN)</span>
<span class="highlight">          ON COMMIT DROP</span>
        ;
psql:variables_include_debugging.sql:4: ERROR:  syntax error at or near "CREATE"
LINE 4:         CREATE TEMP TABLE "prechecks" (value BOOLEAN)</code></pre>

Well that's not going to work.  It doesn't look like our query was loaded into the temp table.

The problem here is that the <code>\include</code> and <code>\set</code> don't really belong in the query file.  If we were using the query interactively, the best way would be to <code>\include</code> and <code>
\set</code> in the terminal, rather than in the query directly.

<pre><code>postgres=# \include '/queries/utils/percent.sql'
CREATE FUNCTION
postgres=# \set film_name 'Agent Truman'
postgres=# \include variables_include_debugging.sql
 first_name | last_name | staff_rental | total_rental | pct_of_rental
------------+-----------+--------------+--------------+---------------
 Mike       | Hillyer   |           11 |           21 |         52.38
 Jon        | Stephens  |           10 |           21 |         47.62
(2 rows)
</code></pre>

Let's remove those from the query file and put them in the test file instead:

<pre><code><span class="highlight">-- \include '/queries/utils/percent.sql'</span>
<span class="highlight">-- \set film_name 'Agent Truman'</span>
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
FROM summary</code></pre>

<pre><code><span class="highlight">\set film_name 'Agent Truman'</span>
<span class="highlight">\include '/queries/utils/percent.sql'</span>
\set query '/queries/variables_include_debugging.sql'
:setup_test
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/variables_include_debugging.sql"
)
:evaluate_test
:cleanup_test</code></pre>

And run the test file again with queries echo on:

<pre><code>export STF_ECHO='queries'; ./runner.sh variables_include_debugging.sql
 ●CREATE OR REPLACE FUNCTION PERCENT(numerator anycompatible, denominator anycompatible)
RETURNS numeric LANGUAGE plpgsql AS $$
BEGIN
    RETURN ROUND(numerator::numeric / denominator::numeric * 100, 2);
END $$;
BEGIN;
CREATE TEMP TABLE "/queries/variables_include_debugging.sql"
            ON COMMIT DROP
            AS

WITH film_by_staff AS (
  SELECT
     COUNT(film.title) AS staff_rental
    ,staff.first_name
    ,staff.last_name
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
  JOIN staff USING(staff_id)
  WHERE film.title = 'Agent Truman'
  GROUP BY staff_id
), film_total AS (
  SELECT
    COUNT(*) AS total_rental
  FROM rental
  JOIN inventory USING(inventory_id)
  JOIN film USING(film_id)
  WHERE film.title = 'Agent Truman'
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
          ;
CREATE TEMP TABLE "prechecks" (value BOOLEAN)
          ON COMMIT DROP
        ;
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/variables_include_debugging.sql"
)
        INSERT INTO stf.test_results (
           run_id
          ,filename
          ,actual
          ,expect
          ,did_pass
          ,text
        )
        SELECT
           1661659229 AS run_id
          ,'variables_include_debugging.sql' AS filename
          ,actual.value AS actual
          ,expect.value AS expect
          ,actual.value IS NOT DISTINCT FROM expect.value AS did_pass
          ,text.value AS text
        FROM actual
        FULL JOIN expect    ON TRUE
        FULL JOIN text      ON TRUE
        ;
CREATE TEMP TABLE IF NOT EXISTS "prechecks" (value BOOLEAN)
        ;
WITH latest_test_run AS (
          SELECT * FROM stf.test_results
          ORDER BY id DESC
          LIMIT 1
        ), aggregated_prechecks AS (
          SELECT
             latest_test_run.id AS id
             ,ARRAY_REMOVE(ARRAY_AGG(prechecks.value), NULL) AS value
          FROM latest_test_run
          FULL JOIN "prechecks" ON TRUE
          GROUP BY latest_test_run.id
        )
        UPDATE stf.test_results
        SET precheck = aggregated_prechecks.value
        FROM aggregated_prechecks
        WHERE aggregated_prechecks.id = stf.test_results.id
        ;
COMMIT;

 actual | expect | did_pass |               text
--------+--------+----------+-----------------------------------
 100.00 | 100    | true     | the percentages add up to 100 pct
(1 row)
</code></pre>

Much better.  When things aren't working as expected <code>STF_ECHO='queries'</code> is a very helpful way to figure out what's going wrong.

## Bonus

A test like this also a great example of when to use a precheck.  What if there were no rentals for <strong>Agent Truman</strong>?  With a simple precheck our final test looks likes this:

<pre><code>\set film_name 'Agent Truman'
\include '/queries/utils/percent.sql'
\set query '/queries/variables_include_debugging.sql'
:setup_test
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
<span class="highlight">), precheck_there_are_rentals AS (</span>
<span class="highlight">  INSERT INTO :"prechecks" (value)</span>
<span class="highlight">  SELECT COALESCE(SUM(staff_rental) > 0, FALSE)</span>
<span class="highlight">  FROM "/queries/variables_include_debugging.sql"</span>
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/variables_include_debugging.sql"
)
:evaluate_test
:cleanup_test
</code></pre>

<pre><code>./runner.sh variables_include_debugging.sql
 ●
 actual | expect | did_pass |               text
--------+--------+----------+-----------------------------------
 100.00 | 100    | true     | the percentages add up to 100 pct
(1 row)
</code></pre>

Now we can get back to the aurora and when Holcombs back online and let's us know what films the CEO likes we can plug those and also, as we were warned "better be right."  Just another Saturday at StreamBuster!
