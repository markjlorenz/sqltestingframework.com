# Precheck Assertions

Goal: Guard against "errors of equality" where your test passes, but not for the reasons you thought it would.

## Setup

It's the end of the quater at StreamBuster, the buzzy tech startup that's disrupting the streaming video market.  At StreamBuster we believe that there's a billion dollar market for the game-changing convenience that comes from driving to a store, picking up a physical disk (if there's a good one in stock anyway) and driving home with it to enjoy with friends and family.Think of the <em>thrill</em> of the hunt, when a movie you want to watch is in stock.  Think about how much accomplishment you'll feel about having "brought home the bacon" to an adoring spouse and children.  Streaming is dead, people want StreamBuster stores.

The executive team has decided that a friendly competition between stores would motivate the teams and increase sales.  You've been asked to create a report that shows sales by store by month.

## Get to work

The query is simple enough:

<pre><code>
SELECT
   store.store_id
  ,DATE_PART('month', payment_date) AS payment_month
  ,SUM(payment.amount) AS total_payment
FROM store
JOIN staff USING(store_id)
JOIN payment USING(staff_id)
GROUP BY store_id, DATE_PART('month', payment_date)
;
</code></pre>

Here we make use of the <code>USING</code> keyword to make the query shorter and easier to read.

With a query that does a roll-up like this, rolling stores and dates up into an aggregate, it's usually a good idea to spot-check a few to make sure that the roll-up is right.  This is straightforward with SQL Testing Framework:

<pre><code>
\set query /queries/sales-by-store.sql
:setup_test
WITH text AS (
  SELECT 'Store #1 has the right number of sales' AS value
), expect AS (
  SELECT
    SUM(payment.amount) AS value
  FROM store
  JOIN staff USING(store_id)
  JOIN payment USING(staff_id)
  WHERE store_id = 3
    AND DATE_PART('month', payment_date) = 3
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 3
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
</code></pre>

We're just checking to make sure that the roll up for store #3 in March is correct.  The test runner gives us a passing test:

<pre><code>
 actual | expect | did_pass |                  text
--------+--------+----------+----------------------------------------
        |        | true     | Store #1 has the right number of sales
(1 row)
</code></pre>

Wait a minute, the runner says our test passed, but why are <code>actual</code> and <code>expect</code> both empty?  That's not what we were expecting!

## Precheck Assertions

Upon closer inspection, we find that there is no Store #3.

<pre><code>
postgres=# SELECT * FROM store;
 store_id | manager_staff_id | address_id |     last_update
----------+------------------+------------+---------------------
        1 |                1 |          1 | 2006-02-15 09:57:12
        2 |                2 |          2 | 2006-02-15 09:57:12
(2 rows)
</code></pre>

This of "error of equality" is a common source of test-related errors.  Our test was technically correct, but because of the way we wrote it, our <em>intent</em> wasn't actually tested.

SQL Testing Framework has a "Precheck Assertions" feature to help guard against this kind of error.  We need to test that the <code>expect</code> and <code>actual</code> are equal, <strong>and also</strong> that they contain reasonable values.

Using the <code>prechecks</code> temporary table, we can easily check for errors of equality:

<pre><code>
\set query /queries/sales-by-store.sql
:setup_test
WITH text AS (
  SELECT 'Store #3 has the right number of sales' AS value
), expect AS (
  SELECT
    SUM(payment.amount) AS value
  FROM store
  JOIN staff USING(store_id)
  JOIN payment USING(staff_id)
  WHERE store_id = 3
    AND DATE_PART('month', payment_date) = 3
), precheck_not_blank AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(value) > 0, FALSE)
  FROM expect
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 3
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
</code></pre>

The new stuff is in the <code>precheck_not_blank</code> common table expression.

<pre><code>
), precheck_not_blank AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(value) > 0, FALSE)
  FROM expect
</code></pre>

The <code>prechecks</code> table has one <code>BOOLEAN</code> column that the test runner will inspect.  Now our test runner output looks like this:

<pre><code>
 actual | expect | did_pass |                  text
--------+--------+----------+----------------------------------------
<span class="failing-test">        |        | f-pre    | Store #3 has the right number of sales</span>
(1 row)
</code></pre>

In the <code>did_pass</code> column, the value of <code><span class=failing-test">f-pre<span></code> tells us that the test failed because of a failed precheck assertion.

Let's fix our test, but using Store #1 as the sample, and run again:

<pre><code>
\set query /queries/sales-by-store.sql
:setup_test
WITH text AS (
  SELECT 'Store #1 has the right number of sales' AS value
), expect AS (
  SELECT
    SUM(payment.amount) AS value
  FROM store
  JOIN staff USING(store_id)
  JOIN payment USING(staff_id)
  WHERE store_id = 1
    AND DATE_PART('month', payment_date) = 3
), precheck_not_blank AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(value) > 0, FALSE)
  FROM expect
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 1
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
</code></pre>

<pre><code>
  actual  |  expect  | did_pass |                  text
----------+----------+----------+----------------------------------------
 11776.83 | 11776.83 | true     | Store #1 has the right number of sales
(1 row)
</code></pre>

Much better, now our test is passing, and it's passing for the right reasons- because Store #1 exists, has sales, and has the right amount of sales.

## Even more precheck assertions

We can add as many precheck assertions as we like. Unless they are all <code>TRUE</code> the test will be marked as <code>f-pre</code>.  Here's an example with two precheck assertions:

<pre><code>
\set query /queries/sales-by-store.sql
:setup_test
WITH text AS (
  SELECT 'Store #1 has the right number of sales' AS value
), expect AS (
  SELECT
    SUM(payment.amount) AS value
  FROM store
  JOIN staff USING(store_id)
  JOIN payment USING(staff_id)
  WHERE store_id = 1
    AND DATE_PART('month', payment_date) = 3
), precheck_not_blank AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(value) > 0, FALSE)
  FROM expect
), precheck_that_always_fails AS (
 INSERT INTO :"prechecks" (value)
 SELECT FALSE
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 1
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
</code></pre>

Of course this a contrived example, you'd never actually want a precheck assertion that always fails.  For demonstration purposes, our test runner output is failing again:

<pre><code>
  actual  |  expect  | did_pass |                  text
----------+----------+----------+----------------------------------------
<span class="failing-test"> 11776.83 | 11776.83 | f-pre    | Store #1 has the right number of sales</span>
(1 row)
</code></pre>

If you have lots of precheck assertions and need to know which on specifically failed, the result of each precheck is available in the <code>test_results</code> table:

<pre><code>
postgres=# SELECT
   id,
  ,precheck
  ,filename
  ,text
FROM stf.test_results
;

 id | precheck |           filename           |                        text
----+----------+------------------------------+-----------------------------------------------------
 31 | {}       | sales-by-store.sql           | Store #1 has the right number of sales
 32 | {f}      | sales-by-store.sql           | Store #1 has the right number of sales
 33 | {t}      | sales-by-store.sql           | Store #1 has the right number of sales
 34 | {f,t}    | sales-by-store.sql           | Store #1 has the right number of sales
(34 rows)
</code></pre>

Once again, SQL Testing Framework has saved us from making a silly mistake!
