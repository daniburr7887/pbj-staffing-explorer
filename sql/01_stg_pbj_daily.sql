-- One row per facility per day, typed and renamed.
--
-- Hour groupings follow CMS's Total Nurse Staffing definition:
--   RN          = RN + RN Director of Nursing + RN admin
--   LPN         = LPN + LPN admin
--   Nurse aide  = CNA + nurse aide in training + medication aide
-- Every category is split into employee (_emp) and contract (_ctr) hours.
CREATE OR REPLACE TABLE stg_pbj_daily AS
SELECT
    PROVNUM                                   AS provnum,
    PROVNAME                                  AS facility_name,
    CITY                                      AS city,
    STATE                                     AS state,
    COUNTY_NAME                               AS county_name,
    COUNTY_FIPS                               AS county_code,  -- 3-digit county part only; PBJ has no state FIPS
    CY_Qtr                                    AS cy_quarter,
    strptime(WorkDate, '%Y%m%d')::DATE        AS work_date,
    dayofweek(strptime(WorkDate, '%Y%m%d')) IN (0, 6) AS is_weekend,
    MDScensus::INTEGER                        AS census,

    (Hrs_RNDON + Hrs_RNadmin + Hrs_RN)::DOUBLE                 AS hrs_rn,
    (Hrs_RNDON_ctr + Hrs_RNadmin_ctr + Hrs_RN_ctr)::DOUBLE     AS hrs_rn_ctr,
    (Hrs_LPNadmin + Hrs_LPN)::DOUBLE                           AS hrs_lpn,
    (Hrs_LPNadmin_ctr + Hrs_LPN_ctr)::DOUBLE                   AS hrs_lpn_ctr,
    (Hrs_CNA + Hrs_NAtrn + Hrs_MedAide)::DOUBLE                AS hrs_aide,
    (Hrs_CNA_ctr + Hrs_NAtrn_ctr + Hrs_MedAide_ctr)::DOUBLE    AS hrs_aide_ctr
FROM raw_pbj_daily;
