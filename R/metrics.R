# Staffing metrics.
#
# Marts store summed hours and resident days, never pre-computed ratios.
# Ratios are always computed as sum(hours) / sum(resident days) at whatever
# grain is being displayed. Averaging daily or facility-level ratios gives
# small facilities the same weight as large ones and does not match CMS.

safe_divide <- function(numerator, denominator) {
  ifelse(is.na(denominator) | denominator == 0, NA_real_, numerator / denominator)
}

# Hours per resident day (HPRD), the standard CMS staffing measure.
hprd <- function(hours, resident_days) {
  safe_divide(hours, resident_days)
}

# Share of hours worked by contract (agency) staff rather than employees.
contract_share <- function(contract_hours, total_hours) {
  safe_divide(contract_hours, total_hours)
}

# Add ratio columns to a data frame that already has summed hours and
# resident days (e.g. a facility-month or state-month table).
add_ratios <- function(df) {
  dplyr::mutate(
    df,
    total_hprd = hprd(hrs_total, resident_days),
    rn_hprd = hprd(hrs_rn, resident_days),
    contract_share = contract_share(hrs_total_ctr, hrs_total),
    weekend_hprd = hprd(weekend_hrs_total, weekend_resident_days),
    weekday_hprd = hprd(hrs_total - weekend_hrs_total, resident_days - weekend_resident_days)
  )
}

# Roll a facility-month data frame up to any grain, e.g.
#   summarise_staffing(df, state, month)
summarise_staffing <- function(df, ...) {
  df |>
    dplyr::group_by(...) |>
    dplyr::summarise(
      facilities = dplyr::n_distinct(provnum),
      resident_days = sum(resident_days),
      hrs_total = sum(hrs_total),
      hrs_rn = sum(hrs_rn),
      hrs_total_ctr = sum(hrs_total_ctr),
      weekend_resident_days = sum(weekend_resident_days),
      weekend_hrs_total = sum(weekend_hrs_total),
      .groups = "drop"
    ) |>
    add_ratios()
}
