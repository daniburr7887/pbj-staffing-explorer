# DuckDB connection helpers.
#
# The warehouse is a single DuckDB file built by pipeline/run_pipeline.R.
# The Shiny app and the Slack bot open it read-only, so a long-running
# dashboard session can never hold a write lock the pipeline has to wait on.

pbj_db_path <- function() {
  Sys.getenv("PBJ_DB_PATH", "data/pbj.duckdb")
}

pbj_connect <- function(read_only = TRUE, path = pbj_db_path()) {
  if (read_only && !file.exists(path)) {
    stop("No warehouse at ", path, ". Run `Rscript pipeline/run_pipeline.R` first.")
  }
  DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = read_only)
}
