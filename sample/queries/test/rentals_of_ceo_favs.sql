\set film_name 'Agent Truman'
\include '/queries/utils/percent.sql'
\set query '/queries/variables_include_debugging.sql'
:setup_test
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
), precheck_there_are_rentals AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(staff_rental) > 0, FALSE)
  FROM "/queries/variables_include_debugging.sql"
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/variables_include_debugging.sql"
)
:evaluate_test
:cleanup_test
