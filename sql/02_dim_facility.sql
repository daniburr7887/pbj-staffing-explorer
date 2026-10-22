-- One row per facility, using the most recently reported name and location
-- (facilities get renamed and change ownership between quarters).
CREATE OR REPLACE TABLE dim_facility AS
SELECT
    provnum,
    arg_max(facility_name, work_date) AS facility_name,
    arg_max(city, work_date)          AS city,
    arg_max(state, work_date)         AS state,
    arg_max(county_name, work_date)   AS county_name,
    arg_max(county_code, work_date)   AS county_code,
    min(work_date)                    AS first_reported,
    max(work_date)                    AS last_reported
FROM stg_pbj_daily
GROUP BY provnum;
