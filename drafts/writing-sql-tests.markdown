# Writing SQL Tests

> Goal: Work with an unfamiliar dataset, and be confident the in the result of our analysis

## Setup

Let's image that we were just hired by a buzzy tech startup that's disrupting the streaming video market.  At StreamBuster we believe that there's a billion dollar market for the game-changing convenience that comes from driving to a store, picking up a physical disk (if there's a good one in stock anyway) and driving home with it to enjoy with friends and family.Think of the /thrill/ of the hunt, when a movie you want to watch is in stock.  Think about how much accomplishment you'll feel about having "brought home the bacon" to an adoring spouse and children.  Streaming is dead, people want StreamBuster stores.

As the new hot-shot analyst, your team has asked you to figure out: <strong>how many rental payments has the company received in the last week?  Today is 09-August-2005.</strong>

<blockquote>
Get a copy of the StreamBuster database, so you can following along at home:
<pre>
  <code>
curl \
  --location \
  --remote-header-name \
  --remote-name \
https://github.com/robconery/dvdrental/raw/master/dvdrental.tar > dvdrental.tar
  </code>
</pre>

Startup your database:
<pre>
  <code>
export PG_PASSWORD="password"
export PG_PORT="5432"

docker run -it --rm \
  --publish "$PG_PORT":5432 \
	--env POSTGRES_PASSWORD="$PG_PASSWORD" \
postgres
  </code>
</pre>

Load the data into your database:
<pre>
  <code>
docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work \
  --workdir /work \
postgres pg_restore \
  -h host.docker.internal \
  -p "$PG_PORT" \
  -U postgres \
  --verbose \
  --dbname postgres \
  ./dvdrental.tar
  </code>
</pre>
</blockquote>

Let's get to work.  It's a good practice to start with SQL Testing Framework, before you start writing queries:

<pre>
  <code>
mkdir queries
cd queries
git clone git@github.com:markjlorenz/sqltestingframework.git
  </code>
</pre>

Now we can connect to StreamBuster's database, and have a quick look around to see how they've structured their database:

<pre>
  <code>
docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work \
  --workdir /work \
postgres psql \
  -h host.docker.internal \
  -p "$PG_PORT" \
  -U postgres

postgres=# \dt

                List of relations
 Schema |       Name       | Type  |  Owner
--------+------------------+-------+----------
 public | actor            | table | postgres
 public | address          | table | postgres
 public | category         | table | postgres
 public | city             | table | postgres
 public | country          | table | postgres
 public | customer         | table | postgres
 public | film             | table | postgres
 public | film_actor       | table | postgres
 public | film_category    | table | postgres
 public | inventory        | table | postgres
 public | language         | table | postgres
 public | payment          | table | postgres
 public | rental           | table | postgres
 public | staff            | table | postgres
 public | store            | table | postgres
 public | tmp_test_results | table | postgres
(16 rows)
  </code>
</pre>

It looks like a pretty nicely normalized database.  Feeling good about the decision to join this startup, we are crushing it already.  What infomration is available to us in the <code>rental</code> field?

<pre>
  <code>
postgres=# \d rental

                                               Table "public.rental"
    Column    |            Type             | Collation | Nullable |                  Default
--------------+-----------------------------+-----------+----------+-------------------------------------------
 rental_id    | integer                     |           | not null | nextval('rental_rental_id_seq'::regclass)
 rental_date  | timestamp without time zone |           | not null |
 inventory_id | integer                     |           | not null |
 customer_id  | smallint                    |           | not null |
 return_date  | timestamp without time zone |           |          |
 staff_id     | smallint                    |           | not null |
 last_update  | timestamp without time zone |           | not null | now()
  </code>
</pre>

This will work.  We should be able to go home early today, drink an IPA and trade x-men cards with our friends!  Let's write a query in the <code>queries/</code> directory called <code>last-week-sales.sql</code>  We can find the dollar amount of rentals by:
<pre>
  <code>
-- queries/last-week-sales.sql
--
SELECT
  SUM(payment.amount)::money
FROM rental
JOIN payment
  ON payment.rental_id = rental.rental_id
WHERE rental.rental_date > '2005-08-02'    -- today is 09-August-2005
;

    sum
------------
 $21,767.03
(1 row)
  </code>
</pre>

Very nice. This company is doing great, and I'm sure your stock options will be work billions.  Before we had this in to the CFO, let's use the SQL Testing Framework to sanity check our work.

We might want to know if a <code>rental</code> can have more than one <code>payment</code>.  We don't think StreamBuster offers consumer financing, but that could be the next pivot.  Let's use the SQL Testing Framework to check:

<pre>
  <code>
-- queries/test/last-week-sales.sql
--
WITH text AS (
  SELECT 'Rentals can only have one payment' AS value
), expect AS (
  SELECT 1 AS value
), actual AS (
  SELECT
    COUNT(rental_id) AS value
  FROM payment
  GROUP BY rental_id
  ORDER BY COUNT(rental_id) DESC
  LIMIT 1
)
:evaluate_test;
  </code>
</pre>

The SQL Tesing Framework has just a few things that it needs from us as users:
<ul>
  <li>A Common table expression (CTE) for <code>text</code>.  This will be how the test is identified in the test report.</li>
  <li>A CTE for <code>expect</code>.  This is the value we expect to get.</li>
  <li>A CTE for <code>actual</code>.  The result of <code>acutal</code> will be compared for equality with the value of <code>expect</code>.  SQL Test Framwork uses <code>IS NOT DISTINCT FROM</code>, rather than <code>=</code> for the check so <code>NULL</code> can be used in <code>expect</code> or <code>actual</code>. </li>
  <li>A call to <code>:evaluate_test;</code>  This how you tell SQL Testing Framekwork that it should evaluate a test case on the CTEs above it.</li>
</ul>

<pre>
  <code>
$ cd ~/queries/test
$ ./runner.sh
.
 actual | expect | did_pass |               text
--------+--------+----------+-----------------------------------
<span class="failing-test"> 5      | 1      | f        | Rentals can only have one payment</span>
(1 row)
  </code>
</pre>

Oh no!  It looks like StreamBuster has been offering consumer credit. In some cases 5 payments were made for one rental.  This is concerning, let's check a few more things.  Can a payment happen before a rental?

<pre>
  <code>
WITH text AS (
  SELECT 'Payments can not happen before rentals' AS value
), expect AS (
  SELECT 0 AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM rental
  JOIN payment
    ON payment.rental_id = rental.rental_id
  WHERE payment.payment_date < rental.rental_date
)
:evaluate_test;
  </code>
</pre>

<pre>
  <code>
$ ./runner.sh
.
 actual | expect | did_pass |                  text
--------+--------+----------+----------------------------------------
<span class="failing-test">  5      | 1      | f        | Rentals can only have one payment</span>
 0      | 0      | t        | Payments can not happen before rentals
(2 rows)
  </code>
</pre>

Ok, good- at least StreamBuster isnt' accepting pre-payments for rentals.  I wonder how much time StreamBuster gives their customers to pay.  The CEO mentioned something about cash flow at the All-Hands bar crawl.

<pre>
  <code>
WITH text AS (
  SELECT 'Most renters make a payment within 60 days' AS value
), expect AS (
  SELECT 60 AS value
), actual AS (
  SELECT
)
:evaluate_test;
  </code>
</pre>

<pre>
  <code>
$ ./runner.sh
.
 actual | expect | did_pass |                  text
--------+--------+----------+----------------------------------------
<span class="failing-test">  5      | 1      | f        | Rentals can only have one payment</span>
 0                        | 0       | t        | Payments can not happen before rentals
<span class="failing-test"> 607 days 38:33:28.119213 | 60 days | f        | Most renters make their last payment within 60 days </span>
(3 rows)
  </code>
</pre>

This is not good.  It looks like on average, it's taking renters 607 days to make their last payment.  This startup has fantastic revenue, but there probably isn't enough cash in the bank to pay sea shanty quitntet that was in the office yestereday.

Let's check one more thing before handing in our resignation.  In our original query, we looked at revenue in the last two week with <code>WHERE rental.rental_date > '2005-08-02' -- today is 09-August-2005</code>, assuming that rentals in the future are not possible.  Let's check:

<pre>
  <code>
\set today '\'2005-08-09\'::date'
WITH text AS (
  SELECT 'Rentals can not happen in the future' AS value
), expect AS (
  SELECT 0 AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM payment
  WHERE payment.paymement_date > :today
)
:evaluate_test;
\unset today
  </code>
</pre>

<pre>
  <code>
$ ./runner.sh
.
 actual | expect | did_pass |                  text
--------+--------+----------+----------------------------------------
<span class="failing-test">  5      | 1      | f        | Rentals can only have one payment</span>
 0                        | 0       | t        | Payments can not happen before rentals
<span class="failing-test"> 607 days 38:33:28.119213 | 60 days | f        | Most renters make their last payment within 60 days</span>
<span class="failing-test"> 14596                    | 0       | f        | Payments can not happen in the future</span>
(4 rows)
  </code>
</pre>

Since payments are happening in the future, we need to re-think our original query.  If we want to know how many were recieved in the last week, well need to change our query like this:

<pre>
  <code>
\set today '\'2005-08-09\'::date'
SELECT
  SUM(payment.amount)::money
FROM rental
JOIN payment
  ON payment.rental_id = rental.rental_id
WHERE rental.rental_date BETWEEN :today - '7 days'::interval AND :today
;

    sum
-----------
 $2,726.57
(1 row)
  </code>
</pre>

This is significantly less exciting than we had originally thought ($21,767.03), and we should probably ask the CFO how they want to handle payments that are being made in the future 🤷‍♂️.

SQL Testing Framework has given you a simple workflow to check the assumptions you made about the dataset and prevented us from deliverying a wildly over-inflated two week payments number!


