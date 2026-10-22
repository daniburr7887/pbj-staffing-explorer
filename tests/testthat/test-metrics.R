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
    hrs_total_ctr = c(40, 0)
  )
  out <- summarise_staffing(df, state)

  # Weighted: 1000 / 300. A naive mean of facility ratios would give 3.5.
  expect_equal(out$total_hprd, 1000 / 300)
  expect_equal(out$contract_share, 40 / 1000)
})
