-- One row per facility per month: summed hours and resident days.
--
-- Stores sums, not ratios, so any rollup (state, county, quarter) can
-- recompute HPRD correctly as sum(hours) / sum(resident_days).
-- Days with no residents are excluded, matching CMS methodology.
CREATE OR REPLACE TABLE fct_facility_month AS
SELECT
    provnum,
    date_trunc('month', work_date)::DATE                AS month,
    count(*)                                            AS days_reported,
    sum(census)                                         AS resident_days,
    sum(hrs_rn)                                         AS hrs_rn,
    sum(hrs_lpn)                                        AS hrs_lpn,
    sum(hrs_aide)                                       AS hrs_aide,
    sum(hrs_rn + hrs_lpn + hrs_aide)                    AS hrs_total,
    sum(hrs_rn_ctr + hrs_lpn_ctr + hrs_aide_ctr)        AS hrs_total_ctr,
    sum(census) FILTER (WHERE is_weekend)               AS weekend_resident_days,
    sum(hrs_rn + hrs_lpn + hrs_aide) FILTER (WHERE is_weekend) AS weekend_hrs_total
FROM stg_pbj_daily
WHERE census > 0
GROUP BY ALL;
