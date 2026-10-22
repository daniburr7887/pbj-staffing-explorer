# Build the warehouse: load raw PBJ CSVs, then run the SQL models in order.
#
# Kept separate from pipeline/run_pipeline.R so the tests can build a
# warehouse from a small fixture CSV in an in-memory database.

# PROVNUM and COUNTY_FIPS have leading zeros ("015009", "059"). Type
# inference reads them as integers and silently drops the zeros, which
# breaks joins to every other CMS dataset. WorkDate is YYYYMMDD text.
PBJ_RAW_TYPES <- "{'PROVNUM': 'VARCHAR', 'COUNTY_FIPS': 'VARCHAR', 'WorkDate': 'VARCHAR', 'CY_Qtr': 'VARCHAR'}"

load_raw_pbj <- function(con, csv_paths) {
  file_list <- paste0("'", normalizePath(csv_paths), "'", collapse = ", ")
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE TABLE raw_pbj_daily AS ",
    "SELECT * FROM read_csv([", file_list, "], header = true, ",
    "types = ", PBJ_RAW_TYPES, ", union_by_name = true)"
  ))
}

run_models <- function(con, sql_dir = "sql") {
  model_files <- sort(list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE))
  for (path in model_files) {
    message("Running ", basename(path))
    DBI::dbExecute(con, paste(readLines(path), collapse = "\n"))
  }
  invisible(model_files)
}

build_warehouse <- function(con, csv_paths, sql_dir = "sql") {
  load_raw_pbj(con, csv_paths)
  run_models(con, sql_dir)
}
