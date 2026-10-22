test_that("provider numbers keep their leading zeros", {
  con <- fixture_warehouse()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ids <- DBI::dbGetQuery(con, "SELECT provnum FROM dim_facility ORDER BY provnum")$provnum
  expect_equal(ids, c("015009", "155001"))
})

test_that("facility-month sums match hand-calculated values", {
  con <- fixture_warehouse()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  jan <- DBI::dbGetQuery(con, "
    SELECT * FROM fct_facility_month
    WHERE provnum = '015009' AND month = DATE '2026-01-01'
  ")

  # The zero-census day (Jan 6) is excluded.
  expect_equal(jan$days_reported, 2)
  expect_equal(jan$resident_days, 100)
  expect_equal(jan$hrs_total, 400)
  expect_equal(jan$hrs_total_ctr, 40)
  # Jan 3 2026 is a Saturday.
  expect_equal(jan$weekend_resident_days, 50)
  expect_equal(jan$weekend_hrs_total, 200)
})

test_that("dim_facility uses the most recent facility name", {
  con <- fixture_warehouse()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  name <- DBI::dbGetQuery(con, "SELECT facility_name FROM dim_facility WHERE provnum = '155001'")
  expect_equal(name$facility_name, "NEW NAME NURSING")
})

test_that("state rollup splits months correctly", {
  con <- fixture_warehouse()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ind <- DBI::dbGetQuery(con, "SELECT month, hrs_total FROM agg_state_month WHERE state = 'IN' ORDER BY month")
  expect_equal(ind$month, as.Date(c("2025-12-01", "2026-01-01")))
  expect_equal(ind$hrs_total, c(600, 600))
})

test_that("app data round-trips through Parquet", {
  con <- fixture_warehouse()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  out_dir <- withr::local_tempdir()
  export_app_data(con, out_dir)

  app_con <- pbj_app_connect(out_dir)
  on.exit(DBI::dbDisconnect(app_con, shutdown = TRUE), add = TRUE)

  expect_setequal(DBI::dbListTables(app_con), APP_TABLES)
  for (table in APP_TABLES) {
    query <- paste("SELECT * FROM", table, "ORDER BY ALL")
    expect_equal(DBI::dbGetQuery(app_con, query), DBI::dbGetQuery(con, query))
  }
  # Leading zeros survive the round trip.
  expect_true("015009" %in% DBI::dbGetQuery(app_con, "SELECT provnum FROM dim_facility")$provnum)
})
