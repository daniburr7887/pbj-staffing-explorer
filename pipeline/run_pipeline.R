# Download the latest PBJ quarters, (re)build the DuckDB warehouse, and
# export the app tables to app_data/.
#
# Usage (from the repo root):
#   Rscript pipeline/run_pipeline.R          # latest 4 quarters
#   Rscript pipeline/run_pipeline.R 8        # latest 8 quarters
#
# Each quarterly CSV is ~1.3M rows (~15k facilities x ~90 days). Files are
# cached in data/raw/, so re-runs only download quarters that are new.

for (f in list.files("R", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
n_quarters <- if (length(args) > 0) as.integer(args[[1]]) else 4

raw_dir <- "data/raw"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

quarters <- pbj_quarters(n_quarters)
message("Using quarters: ", paste(quarters$quarter_start, collapse = ", "))

options(timeout = 1800)
csv_paths <- vapply(seq_len(nrow(quarters)), function(i) {
  path <- file.path(raw_dir, paste0("pbj_", quarters$quarter_start[[i]], ".csv"))
  if (!file.exists(path)) {
    message("Downloading ", quarters$quarter_start[[i]])
    tmp <- paste0(path, ".part")
    utils::download.file(quarters$csv_url[[i]], tmp, mode = "wb", quiet = TRUE)
    # CMS files are Windows-1252 (e.g. curly apostrophes in facility names),
    # which DuckDB rejects as invalid UTF-8. Re-encode once at download.
    src <- file(tmp, encoding = "CP1252")
    writeLines(readLines(src), path, useBytes = TRUE)
    close(src)
    unlink(tmp)
  }
  path
}, character(1))

# Build into a temp file and swap it in at the end, so a failed run never
# leaves the dashboard pointing at a half-built warehouse.
db_path <- pbj_db_path()
tmp_db <- paste0(db_path, ".building")
unlink(tmp_db)

con <- pbj_connect(read_only = FALSE, path = tmp_db)
build_warehouse(con, csv_paths)
DBI::dbDisconnect(con, shutdown = TRUE)

invisible(file.rename(tmp_db, db_path))
message("Warehouse ready at ", db_path)

con <- pbj_connect(read_only = TRUE)
export_app_data(con)
DBI::dbDisconnect(con, shutdown = TRUE)
message("App data exported to ", app_data_dir(), "/")
