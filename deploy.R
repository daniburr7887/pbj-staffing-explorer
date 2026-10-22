# Deploy the dashboard to shinyapps.io.
#
# Usage (from the repo root):
#   SHINYAPPS_ACCOUNT=<account name> Rscript deploy.R
#
# One-time setup: run the rsconnect::setAccountInfo(...) command from
# shinyapps.io > Account > Tokens. The token stays on your machine.

account <- Sys.getenv("SHINYAPPS_ACCOUNT")
if (account == "") stop("Set SHINYAPPS_ACCOUNT to your shinyapps.io account name.")

# Upload only what the app needs. The default would include data/, which
# holds the ~385 MB local warehouse and raw CSVs.
app_files <- c(
  "app.R",
  list.files("R", full.names = TRUE),
  list.files("app_data", full.names = TRUE)
)

rsconnect::deployApp(
  appDir = ".",
  appFiles = app_files,
  appName = "pbj-staffing-explorer",
  appTitle = "PBJ Staffing Explorer",
  account = account,
  server = "shinyapps.io",
  forceUpdate = TRUE
)
