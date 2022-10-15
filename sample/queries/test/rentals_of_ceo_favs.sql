\set film_name 'Agent Truman'
\include '/queries/utils/percent.sql'
\set query '/queries/rentals_of_ceo_favs.sql'
:setup_test
WITH text AS (
  SELECT 'the percentages add up to 100 pct' AS value
), precheck_there_are_rentals AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(staff_rental) > 0, FALSE)
  FROM "/queries/rentals_of_ceo_favs.sql"
), expect AS (
  SELECT 100 AS value
), actual AS (
  SELECT
    SUM(pct_of_rental) AS value
  FROM "/queries/rentals_of_ceo_favs.sql"
)
:evaluate_test
:cleanup_test
