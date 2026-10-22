# DuckDB connection helpers.
#
# Two data stores:
#   data/pbj.duckdb  full warehouse built by pipeline/run_pipeline.R (local only)
#   app_data/*.parquet  the small tables the app and bot read (committed)

pbj_db_path <- function() {
  Sys.getenv("PBJ_DB_PATH", "data/pbj.duckdb")
}

app_data_dir <- function() {
  Sys.getenv("PBJ_APP_DATA", "app_data")
}

pbj_connect <- function(read_only = TRUE, path = pbj_db_path()) {
  if (read_only && !file.exists(path)) {
    stop("No warehouse at ", path, ". Run `Rscript pipeline/run_pipeline.R` first.")
  }
  DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = read_only)
}

# In-memory DuckDB with a view over each app Parquet file, so app queries
# look the same as warehouse queries. Nothing is written, so there are no
# locks and every app process gets its own connection.
pbj_app_connect <- function(dir = app_data_dir()) {
  con <- DBI::dbConnect(duckdb::duckdb())
  for (path in list.files(dir, pattern = "\\.parquet$", full.names = TRUE)) {
    table <- tools::file_path_sans_ext(basename(path))
    DBI::dbExecute(con, paste0(
      "CREATE VIEW ", table, " AS SELECT * FROM read_parquet('", normalizePath(path), "')"
    ))
  }
  con
}
