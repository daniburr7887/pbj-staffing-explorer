test_that("hprd and contract_share return NA instead of dividing by zero", {
  expect_equal(hprd(400, 100), 4)
  expect_true(is.na(hprd(10, 0)))
  expect_true(is.na(contract_share(5, NA)))
})

test_that("rollups weight by resident days, not by facility", {
  df <- data.frame(
    provnum = c("A", "B"),
    state = "XX",
    resident_days = c(100, 200),
    hrs_total = c(400, 600),   # facility HPRD 4.0 and 3.0
    hrs_rn = c(90, 200),
    hrs_total_ctr = c(40, 0),
    weekend_resident_days = c(30, 60),
    weekend_hrs_total = c(120, 180)
  )
  out <- summarise_staffing(df, state)

  # Weighted: 1000 / 300. A naive mean of facility ratios would give 3.5.
  expect_equal(out$total_hprd, 1000 / 300)
  expect_equal(out$contract_share, 40 / 1000)
})

test_that("weekend and weekday HPRD split the same totals", {
  df <- data.frame(
    resident_days = 100, hrs_total = 380, hrs_rn = 50, hrs_total_ctr = 0,
    weekend_resident_days = 30, weekend_hrs_total = 90  # weekend 3.0, weekday 290/70
  )
  out <- add_ratios(df)
  expect_equal(out$weekend_hprd, 3)
  expect_equal(out$weekday_hprd, 290 / 70)
})

test_that("weekend HPRD is NA, not 0, when no weekend days were reported", {
  df <- data.frame(
    resident_days = 100, hrs_total = 300, hrs_rn = 50, hrs_total_ctr = 0,
    weekend_resident_days = 0, weekend_hrs_total = 0
  )
  expect_true(is.na(add_ratios(df)$weekend_hprd))
})
