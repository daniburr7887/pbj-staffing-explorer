-- County x month rollup for the dashboard's county map.
-- PBJ county codes are only unique within a state, so state is part of the key.
CREATE OR REPLACE TABLE agg_county_month AS
SELECT
    f.state,
    f.county_code,
    any_value(f.county_name)    AS county_name,
    m.month,
    count(DISTINCT m.provnum)   AS facilities,
    sum(m.resident_days)        AS resident_days,
    sum(m.hrs_rn)               AS hrs_rn,
    sum(m.hrs_total)            AS hrs_total,
    sum(m.hrs_total_ctr)        AS hrs_total_ctr,
    sum(m.weekend_resident_days) AS weekend_resident_days,
    sum(m.weekend_hrs_total)    AS weekend_hrs_total
FROM fct_facility_month m
JOIN dim_facility f USING (provnum)
GROUP BY f.state, f.county_code, m.month;
