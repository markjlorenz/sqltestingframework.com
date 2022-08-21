\set mad_max_tbl payment
\set mad_max_col amount
:setup_test
WITH text AS (
  SELECT 'SKEW TEST' AS value
), expect AS (
  SELECT TRUE AS value
), mad_max AS (
  -- one row with `mad` and `max` columns
  -- `mad` is the median absolute deviation
  -- `max` is 6 mad deviations from the median
  -- anything outside of that is probably an outlier
  :get_mad_max
), prechek_no_skew AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(amount) <= 0, FALSE)
  FROM payment
  FULL JOIN mad_max ON TRUE
  WHERE payment.amount > mad_max.max + mad_max.mad
), actual AS (
  SELECT TRUE AS value
)
:evaluate_test
:cleanup_test
