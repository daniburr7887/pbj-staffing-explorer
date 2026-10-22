-- State x month rollup for the dashboard's overview tab and the bot.
CREATE OR REPLACE TABLE agg_state_month AS
SELECT
    f.state,
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
GROUP BY ALL;
