# Design decisions

A running log of choices made and why. Newest at the bottom.

### DuckDB instead of Postgres
The whole warehouse is a single file with no server to run, and the data volume (~5M rows/year) is small for a columnar engine. The pipeline is the only writer, and the app reads exported copies, so a dashboard session can never block a rebuild.

### Discover quarters from the CMS catalog
CMS publishes each quarter as a separate dataset with its own URL. The pipeline reads `data.cms.gov/data.json` and picks the latest N quarters, so new releases need no code change.

### Read ID columns as text
`PROVNUM` ("015009") and `COUNTY_FIPS` ("059") have leading zeros. Default CSV type inference turns them into integers and drops the zeros, which breaks joins to any other CMS dataset. They are explicitly typed `VARCHAR` on load, and a test covers it.

`COUNTY_FIPS` in PBJ is only the 3-digit county part. A full 5-digit FIPS would need a state-code crosswalk, so the column is called `county_code` to avoid implying it is a full FIPS.

### Store sums, compute ratios late
Marts hold summed hours and resident days, never pre-computed HPRD. Averaging facility HPRDs gives a 30-bed facility the same weight as a 300-bed one, which doesn't match how CMS reports. `R/metrics.R` always computes `sum(hours) / sum(resident_days)`, and a test covers the difference.

### Exclude zero-census days
Days with no residents have hours but no resident days. They are dropped from the facility-month fact, matching CMS methodology.

### Build to a temp file, then swap
The pipeline writes `pbj.duckdb.building` and renames it into place only after every model succeeds, so a failed run never leaves the app pointing at a half-built warehouse.

### Server-side facility search
There are ~15k facilities. Sending all of them to a browser `<select>` freezes the page, so the Shiny selectize input loads matches from the server as the user types.

### Deploy small Parquet exports, not the warehouse
The full warehouse (~385 MB for a year) is mostly raw and daily staging data that the app never reads. The pipeline exports only `dim_facility`, `fct_facility_month`, `agg_state_month` and `agg_county_month` to `app_data/*.parquet` (~5 MB), which are committed and deployed with the app. The app opens an in-memory DuckDB with a view over each file, so its SQL is unchanged. Parquet was chosen over a second `.duckdb` file so the deployed app isn't tied to the DuckDB version that built the data.

### Map counties by FIPS code, and say what can't be drawn
County outlines come from the `maps` package and are joined on state + county FIPS code rather than county name, which avoids mismatches like "St. Louis" vs. "st louis". Three gaps are shown to the user instead of hidden:
- **Alaska, Hawaii and territories** have no outlines in the package, so the map shows a message instead.
- **Connecticut** replaced its 8 counties with 9 planning regions in 2022. CMS reports the new regions but the package only has the old counties, so none would match; the map says so instead of drawing an all-gray state.
- **Virginia independent cities** (26 with nursing homes) mostly have no outline. The map caption lists every place with data that isn't drawn.

### Weekend gap
CMS star ratings look at weekend staffing separately because it tends to dip. The fact table stores weekend hours and resident days alongside the totals, so weekday figures are derived as total minus weekend at any grain. A facility-month with no weekend days gets 0, not NULL, so the subtraction never goes missing, and weekend HPRD is NA rather than 0 when there were no weekend resident days.

### Chart design
Charts use ggiraph for hover tooltips. Colors follow one rule per job: the facility is a blue accent against its state in gray (emphasis, not two competing series), weekday vs. weekend are two steps of one blue, and the county map is a single-hue sequential ramp with a separate neutral for "no data". The palette was checked with a colorblind-safety validator.

