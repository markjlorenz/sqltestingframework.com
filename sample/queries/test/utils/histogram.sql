-- Returns a table of histogram stats
-- you need to set `tbl` and `col` before including this script.
-- Useful for debugging with then skew precheck fails.

-- \set tbl payment
-- \set col amount
-- \include test/utils/histogram.sql
WITH smallest (label, value) AS (
  SELECT
     'min'
     ,MIN(:mad_max_col)
  FROM :mad_max_tbl
), largest (label, value) AS (
  SELECT
    'max'
    ,MAX(:mad_max_col)
  FROM :mad_max_tbl
), standard_dev_pop (label, value) AS (
  SELECT
    'stddev_pop'
    ,STDDEV_POP(:mad_max_col)
  FROM :mad_max_tbl
), median (label, value) AS (
  SELECT
     'median'
    ,PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY :mad_max_col)
  FROM :mad_max_tbl
), median_deviations AS (
  SELECT
    ABS(:mad_max_col - median.value) AS absolute_deviation
  FROM :mad_max_tbl
  FULL JOIN median ON TRUE
), mad (label, value) AS ( -- median absoluion deviation
  SELECT
     'MAD'
    ,PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY absolute_deviation)
  FROM median_deviations
), histo (buckets, count) AS (
  SELECT -- Bucket label is where the bucket starts (inclusive)
     -- (WIDTH_BUCKET(:mad_max_col, smallest.count, largest.count, 9) - 1) * (largest.count - smallest.count) / 9 + smallest.count AS buckets
     (WIDTH_BUCKET(:mad_max_col, mad.value * -6 + median.value, mad.value * 6 + median.value, 12) - 1) * mad.value + (median.value - 6) AS buckets
    ,COUNT(*) AS count
  FROM :mad_max_tbl
  FULL JOIN smallest ON TRUE
  FULL JOIN largest  ON TRUE
  FULL JOIN median   ON TRUE
  FULL JOIN mad      ON TRUE
  GROUP BY buckets
  ORDER BY buckets
), nulls (none, none) AS (
  VALUES (NULL::text, NULL::numeric)
)

SELECT * FROM smallest
UNION ALL
SELECT * FROM largest
UNION ALL
SELECT * FROM standard_dev_pop
UNION ALL
SELECT * FROM median
UNION ALL
SELECT * FROM mad
UNION ALL
SELECT * FROM nulls
UNION ALL
SELECT buckets::text, count FROM histo
;
