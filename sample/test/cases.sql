/* Write common table expressions:
    `text`
    `actual`
    `expect`
  each should output one column `value` and one row
  call `:evalute_test`
*/
WITH text AS (
  SELECT 'all staff have a picture' AS value
), actual AS (
  SELECT
    COUNT(*) AS value
  FROM staff
  WHERE picture IS NULL
), expect AS (
  SELECT 0 AS value
)
:evaluate_test;
