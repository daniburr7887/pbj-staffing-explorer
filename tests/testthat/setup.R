root <- testthat::test_path("..", "..")
for (f in list.files(file.path(root, "R"), full.names = TRUE)) source(f)

# Build a throwaway in-memory warehouse from the fixture CSV.
fixture_warehouse <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())
  build_warehouse(
    con,
    csv_paths = testthat::test_path("fixtures", "pbj_sample.csv"),
    sql_dir = file.path(root, "sql")
  )
  con
}
