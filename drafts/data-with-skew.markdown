# Data with Skew


<blockquote>See <a href="writing-sql-tests.html">the SQL Testing Framework 101 tutorial</a> for database setup instructions to follow along on your computer.

<p>For this example we'll also need to modify one of the records:</p>
<pre><code>UPDATE payment SET amount = 999 WHERE payment_id = (
    SELECT MAX(payment_id) FROM payment
)
</code></pre>
</blockquote>

StreamBuster is in fiscal planning season and word has gotten out that the average payment for a rental over the last month was $8.30!  The company plans to double rentals from 182 a month to 364 rentals a month, and everyone is talking about how the revenue target for the sales team is going to be an eye popping $3,021.20 ($8.30 * 364) for the next month.

You're cleaning out the dust from between your keys, when you see a message from your boss, Sandy Holcombs.  Sandy leads sales at StreamBuster.

> Sandy Holcombs is typing...
> Hey there! We have a big number to hit. I was think we should lean in to the most frequently rented titles. If we can double those at $8.30 per rental, then we should be able to hit the sales goal.  Can you run a report for me that shows the best sellers?  Thanks!!!

Sounds easy enough.  Let's write the query:

<pre><code>\set current_date 2006-02-14
SELECT
   film.title
  ,COUNT(film.title) AS rental_count
  ,SUM(payment.amount) AS revenue
FROM rental
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
JOIN payment USING(rental_id)
WHERE rental_date > :'current_date'::date - 30
GROUP BY film_id
ORDER BY rental_count DESC
LIMIT 1
;

    title    | rental_count | revenue
-------------+--------------+---------
 Shock Cabin |            2 |    5.98
(1 row)
</code></pre>

Alright, "Shock Cabin", you're about to receive all of the promotional might that Sandy's team can muster.

Wait a minute, the revenue-per-unit on Shock Cabin, $5.98 / 2 = $2.99, is far less than the $8.30 Sandy was talking about.

Let's write some tests, to make sure that we didn't make a mistake.

<pre><code>\set current_date 2006-02-14
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
  -- It's a good idea to check that the 2 records we assume are there
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(rental_id) = 2, FALSE)
  FROM shock_cabin
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM shock_cabin
  WHERE payment_amounts > 4.00
)
:evaluate_test
:cleanup_test
</code></pre>

<pre><code>actual | expect | did_pass |                   text
--------+--------+----------+-------------------------------------------
 0      | 0      | true     | Shock Cabin is less than $4.00 per rental
(1 row)
</code></pre>

Looks like, Shock Cabin never rented for more than $4.00, so each rental must have been less than $8.30.  I wonder why the average payment per rental Holcombs was talking about is so much higher?

## On average, averages are bad

Sometimes we get results that are "correct" but that lead to bad decision making because of skew in the data.  Averages are very susceptible to this:

<pre><code>1 1 1 1 1 1 1 1 100
</code></pre>

The average is 12.  But if you're pulling numbers out of a random hat, you will never get a 12.  You'll either get 1, or a 100, no matter what, you'll be off by an order of magnitude if you were expecting to pull a 12.

Non-bell-curve, <a href="https://en.wikipedia.org/wiki/Power_law">power law distributions</a> (also called a long-tail) like this are really common with real world data.

In addition to the fact that the average is no where near the real numbers in the population, in the real world, with some cleverness, you can usually think of a way to create selection bias so that if you want just the 1s or just the 100s you can greatly increase your odds of getting either just 1s or just 100s.  Imagine these are stones that weigh 1 gram or 100 grams, when you reach into the hat, it will be very easy to pick a big one or one of the small ones.

Before doing a roll-up like a <code>SUM</code> or an <code>AVERAGE</code> in a query, it's a really good idea to check for skew in the data, so you don't get fooled into think that the world is average.

## Skew precheck

Back at StreamBuster, you're starting to suspect that there are some high-dollar rentals skewing the average payment per rental.  There was that one time when we had Wu-Tang Clan's, <a href="https://en.wikipedia.org/wiki/Once_Upon_a_Time_in_Shaolin">Once Upon a Time in Shaolin</a> i n inventory.

SQL Testing Framework has a simple way to guard against skew in the data by using a special type of precheck assertion:

<pre><code><span class="highlight">\set mad_max_tbl payment</span>
<span class="highlight">\set mad_max_col amount</span>
:setup_test
WITH text AS (
  SELECT 'A sample test with skew precheck' AS value
), expect AS (
  SELECT TRUE AS value
<span class="highlight">), mad_max AS (</span>
<span class="highlight">  -- one row with `mad` and `max` columns</span>
<span class="highlight">  -- `mad` is the median absolute deviation</span>
<span class="highlight">  -- `max` is 6 mad deviations from the median</span>
<span class="highlight">  -- anything outside of that is probably an outlier</span>
<span class="highlight">  :get_mad_max</span>
<span class="highlight">), precheck_no_skew AS (</span>
<span class="highlight">  INSERT INTO :"prechecks" (value)</span>
<span class="highlight">  SELECT COALESCE(COUNT(amount) = 0, FALSE)</span>
<span class="highlight">  FROM payment</span>
<span class="highlight">  FULL JOIN mad_max ON TRUE</span>
<span class="highlight">  WHERE payment.amount > mad_max.max + mad_max.mad</span>
), actual AS (
  SELECT TRUE AS value
)
:evaluate_test
:cleanup_test
</code></pre>

The new concepts are in <span class="highlight">highlight</span>.  Let's break it down:

In the first part, we need to tell SQL Testing Framework what table and column should be checked for skew.  This is done by setting the <code>mad_max_tbl</code> and <code>mad_max_col</code> variables.

<pre><code>\set mad_max_tbl payment
\set mad_max_col amount
</code></pre>

Next, we create a common table expression to hold the results of the skew calculation, and insert the variable <code>:get_mad_max</code> to populate it.

<pre><code\>
), mad_max AS (
  -- one row with `mad` and `max` columns
  -- `mad` is the median absolute deviation
  -- `max` is 6 mad deviations from the median
  -- anything outside of that is probably an outlier
  :get_mad_max
),
</code></pre>

Finally, we follow the usual <a href="/precheck-assertions-for-sql-queries.html">precheck assertion</a> pattern, but use our access to <code>mad_max.max</code> and <code>mad_max.mad</code> to decide if the amount of skew is acceptable.

<pre><code\>
), precheck_no_skew AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(amount) = 0, FALSE)
  FROM payment
  FULL JOIN mad_max ON TRUE
  WHERE payment.amount > mad_max.max + mad_max.mad
)
</code></pre>

## Mad Max: no, not the movie

A little statistics background to help your understanding.  A conventional way to judge variability in a dataset is <a href="https://en.wikipedia.org/wiki/Standard_deviation">standard deviation</a>.  Most databases have the <a href="https://www.postgresql.org/docs/9.1/functions-aggregate.html#:~:text=the%20dependent%20variable)-,stddev(expression),-smallint%2C%20int">built-in aggregate functions to calculation standard deviation.</a>  The manufacturing concept of <a href="https://en.wikipedia.org/wiki/Six_Sigma">six sigma</a> would then say that if there are six standard deviations between the average and the upper/lower specification limit, then a manufacturing process is in good control.

Borrowing those concepts for evaluating skew, we could say that if all of our data points fall within 6 standard deviations from the average, then there can't be any extreme outliers. However, this requires using averages (standard deviation itself is the average deviation).

To stay away from averages, we use the same concepts, but with the median instead of the average, so we get <strong>median absolute deviation (MAD)</strong>, which represents one-unit of deviation and <strong>maximum deviation</strong>, which SQL Testing Framework defaults to 6 median absolution deviations <strong>(6-mad)</strong>.

These concepts show up in the last line of our precheck assertion:

<pre><code\>), precheck_no_skew AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(amount) = 0, FALSE)
  FROM payment
  FULL JOIN mad_max ON TRUE
<span class="highlight">  WHERE payment.amount > mad_max.max + mad_max.mad</span>
)
</code></pre>

We checking for <code>payment.amount</code> values that are greater than 7 median absolute deviations (the 6 default <code>mad</code>s in <code>max</code> plus one more) from the median.

## Finding the skew

Adding this to your tests, we see that there is indeed a skew problem:

<pre><code>\set current_date 2006-02-14
<span class="highlight">\set mad_max_tbl payment</span>
<span class="highlight">\set mad_max_col amount</span>
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
  -- It's a good idea to check that the 2 records we assume are there
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(rental_id) = 2, FALSE)
  FROM shock_cabin
<span class="highlight">), mad_max AS (</span>
<span class="highlight">  :get_mad_max</span>
<span class="highlight">), precheck_no_skew AS (</span>
<span class="highlight">  INSERT INTO :"prechecks" (value)</span>
<span class="highlight">  SELECT COALESCE(COUNT(amount) = 0, FALSE)</span>
<span class="highlight">  FROM payment</span>
<span class="highlight">  FULL JOIN mad_max ON TRUE</span>
<span class="highlight">  WHERE payment.amount > mad_max.max + mad_max.mad</span>
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM shock_cabin
  WHERE payment_amounts > 4.00
)
:evaluate_test
:cleanup_test
</code></pre>

<pre><code>actual | expect | did_pass |                   text
--------+--------+----------+-------------------------------------------
<span class="failing-test"> 0      | 0      | f-pre    | Shock Cabin is less than $4.00 per rental</span>
(1 row)
</code></pre>

That's great to know, but not that helpful on it's own.  Where is the outlier?  How big is it?

To diagnose skew issues, SQL Testing Framework as some additional tools.  Launch a connection to your database so we can see what's going on:

<pre><code>postgres=# \set mad_max_tbl payment
postgres=# \set mad_max_col amount
postgres=# \include test/utils/histogram.sql

         label         |       value
-----------------------+-------------------
 min                   |                 0
 max                   |               999
 stddev_pop            | 8.567842706195115
 median                |              3.99
 MAD                   |                 1
                       |
 -0.009999999999999787 |                24
 0.9900000000000002    |              2721
 1.9900000000000002    |               580
 2.99                  |              3240
 3.99                  |               988
 4.99                  |              3431
 5.99                  |              1188
 6.99                  |              1022
 7.99                  |               622
 8.99                  |               439
 9.99                  |               341
(17 rows)
</code></pre>

<code>test/utils/histogram.sql</code> provides some useful statistics, as well as the bucketization of values in the 6-mad calculation (there are 341 payments of $9.99 or more).  We can also see that the maximum payment is <strong>$999</strong>  It looks like StreamBuster did rent THE WU after all and it's pulling the average way up.

## Bad news for Holcombs

This is bad news for Sandy.  It means she's going to have to either find some more whales to rent THE WU at $999, or rent 757 ($3,021.20 / $3.99) units at (the more likely) mean payment per rental ($3.99)- almost twice the amount of work she was expecting. 💀

