# The SQL Testing Framework API

The SQL Testing Framework API is very simple.  All tests start with a common table expressions (CTE) that include <code>text</code>, <code>expect</code>, and <code>actual</code> expressions and ends with the <code>:evaluat_test</code> variable.

```sql
WITH text AS (
  SELECT 'return_date is never earlier than rental_date' AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM rental
  WHERE return_date < rental_date
), expect AS (
  SELECT 0 AS value
)
:evaluate_test;
```

When testing a query result instead of the data in the database, the same format is followed, but setup and cleanup are added.  The variable <code>:setup_test</code> creates a temp table with a name defined by the<code>:query</code> variable.  This lets us access our query results in <code>expect</code> and <code>acutal</code>.

```sql
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
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 1
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
```

Any expressions that insert <code>TRUE</code> or <code>FALSE</code> values inserted into the <code>:"prechecks"</code> table are evaluated as precheck assertions.  Precheck assertions that are <code>FALSE</code> will cause the test to be marked ask failed, with a <code>did_pass</code> value of <code>f-pre</code>.

```sql
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

```
