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

# Tables the Shiny app reads. Everything else (raw and staging, ~95%
# of the warehouse) stays local.
APP_TABLES <- c("dim_facility", "fct_facility_month", "agg_state_month", "agg_county_month")

# Export the app tables as Parquet so they can be committed and deployed with
# the app. Parquet (unlike a .duckdb file) doesn't tie the deployed app to
# the DuckDB version that built it.
export_app_data <- function(con, out_dir = app_data_dir()) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  for (table in APP_TABLES) {
    path <- file.path(out_dir, paste0(table, ".parquet"))
    DBI::dbExecute(con, paste0(
      "COPY (SELECT * FROM ", table, ") TO '", path, "' (FORMAT PARQUET, COMPRESSION ZSTD)"
    ))
  }
  invisible(file.path(out_dir, paste0(APP_TABLES, ".parquet")))
}
