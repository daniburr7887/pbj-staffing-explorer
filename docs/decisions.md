# Design decisions

A running log of choices made and why. Newest at the bottom.

### DuckDB instead of Postgres
The whole warehouse is a single file with no server to run, and the data volume (~5M rows/year) is small for a columnar engine. The Shiny app and the bot open it read-only, so a dashboard session can't block a pipeline rebuild.

### Discover quarters from the CMS catalog
CMS publishes each quarter as a separate dataset with its own URL. The pipeline reads `data.cms.gov/data.json` and picks the latest N quarters, so new releases need no code change.

### Read ID columns as text
`PROVNUM` ("015009") and `COUNTY_FIPS` ("059") have leading zeros. Default CSV type inference turns them into integers and drops the zeros, which breaks joins to any other CMS dataset. They are explicitly typed `VARCHAR` on load, and a test covers it.

`COUNTY_FIPS` in PBJ is only the 3-digit county part. A full 5-digit FIPS would need a state-code crosswalk, so the column is called `county_code` to avoid implying it is a full FIPS.

### Store sums, compute ratios late
Marts hold summed hours and resident days, never pre-computed HPRD. Averaging facility HPRDs gives a 30-bed facility the same weight as a 300-bed one, which doesn't match how CMS reports. `R/metrics.R` and the bot SQL both compute `sum(hours) / sum(resident_days)`, and a test covers the difference.

### Exclude zero-census days
Days with no residents have hours but no resident days. They are dropped from the facility-month fact, matching CMS methodology.

### Build to a temp file, then swap
The pipeline writes `pbj.duckdb.building` and renames it into place only after every model succeeds, so a failed run never leaves the app pointing at a half-built warehouse.

### Server-side facility search
There are ~15k facilities. Sending all of them to a browser `<select>` freezes the page, so the Shiny selectize input loads matches from the server as the user types.

### Deploy small Parquet exports, not the warehouse
The full warehouse (~385 MB for a year) is mostly raw and daily staging data that the app never reads. The pipeline exports only `dim_facility`, `fct_facility_month` and `agg_state_month` to `app_data/*.parquet` (~5 MB), which are committed and deployed with the app. The app and bot open an in-memory DuckDB with a view over each file, so their SQL is unchanged. Parquet was chosen over a second `.duckdb` file so the deployed app isn't tied to the DuckDB version that built the data.

## Open questions
- **Bot hosting:** Socket Mode on a small always-on host vs. HTTP mode on a serverless platform.
