# Find PBJ Daily Nurse Staffing quarterly CSVs in the CMS data catalog.
#
# CMS publishes each quarter as its own dataset entry in data.json, titled
# "Payroll Based Journal Daily Nurse Staffing : <quarter start date>".
# Reading the catalog (instead of hard-coding URLs) means new quarters are
# picked up automatically when CMS releases them.

CMS_CATALOG_URL <- "https://data.cms.gov/data.json"
PBJ_TITLE_PREFIX <- "Payroll Based Journal Daily Nurse Staffing : "

pbj_quarters <- function(n = 4, catalog_url = CMS_CATALOG_URL) {
  catalog <- jsonlite::fromJSON(catalog_url, simplifyVector = FALSE)

  rows <- lapply(catalog$dataset, function(ds) {
    if (!startsWith(ds$title, PBJ_TITLE_PREFIX)) return(NULL)
    csv <- Filter(function(d) identical(d$format, "CSV"), ds$distribution)
    if (length(csv) == 0) return(NULL)
    data.frame(
      quarter_start = as.Date(sub(PBJ_TITLE_PREFIX, "", ds$title, fixed = TRUE)),
      csv_url = csv[[1]]$downloadURL
    )
  })

  quarters <- do.call(rbind, rows)
  quarters <- quarters[order(quarters$quarter_start, decreasing = TRUE), ]
  head(quarters, n)
}
