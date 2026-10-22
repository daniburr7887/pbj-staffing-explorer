# PBJ Staffing Explorer

How well staffed are U.S. nursing homes, and how much of that staffing comes from agency (contract) workers?

This project turns CMS's public **Payroll-Based Journal (PBJ)** data into a small analytics stack:

- **Pipeline:** finds the latest quarterly files in the CMS catalog, downloads them, and builds a DuckDB warehouse with tested SQL models
- **Dashboard:** an R Shiny app for comparing states and drilling into any of ~15,000 facilities
- **Slack bot:** a `/staffing <facility>` command that returns a facility's staffing summary *(in progress)*

## The data

[PBJ Daily Nurse Staffing](https://data.cms.gov/quality-of-care/payroll-based-journal-daily-nurse-staffing) is payroll-based staffing data that every Medicare/Medicaid-certified nursing home must submit to CMS. Each row is one facility on one day. It contains the resident census and the hours worked by RNs, LPNs and nurse aides, split into employee hours and contract hours. CMS releases one file per quarter, about 1.3M rows each.

### Metrics

| Metric | Definition |
|---|---|
| **Total nurse HPRD** | (RN + LPN + nurse aide hours) ÷ resident days |
| **RN HPRD** | RN hours (incl. Director of Nursing and RN admin) ÷ resident days |
| **Contract share** | Contract hours ÷ total nurse hours |
| **Weekend HPRD** | Total nurse HPRD limited to Saturdays and Sundays |

HPRD = hours per resident day. Every ratio is computed as `sum(hours) / sum(resident days)` at the grain being displayed, never as an average of daily or facility ratios. See [docs/decisions.md](docs/decisions.md).

## Architecture

```
data.cms.gov catalog ──► pipeline/run_pipeline.R ──► data/pbj.duckdb ──► app_data/*.parquet ──┬──► app.R (Shiny)
   (quarterly CSVs)         R/warehouse.R + sql/*.sql    (~385 MB, local)   (~5 MB, committed)   └──► bot/app.py (Slack)
```

| Model | Grain | Purpose |
|---|---|---|
| `stg_pbj_daily` | facility × day | Typed, renamed, hours grouped into RN / LPN / aide, employee vs. contract |
| `dim_facility` | facility | Latest name and location for each facility |
| `fct_facility_month` | facility × month | Summed hours and resident days (zero-census days excluded) |
| `agg_state_month` | state × month | State rollup for the dashboard and bot |

The last three are exported to `app_data/` as Parquet and committed, so the deployed app needs no pipeline run or database server.

## Running it

Requires R ≥ 4.2.

```r
install.packages(c("duckdb", "DBI", "dplyr", "jsonlite", "shiny", "bslib", "DT", "ggplot2", "testthat"))
```

```bash
Rscript -e 'shiny::runApp()'           # launch the dashboard (uses committed app_data/)
Rscript pipeline/run_pipeline.R        # optional: rebuild from the latest 4 CMS quarters
Rscript -e 'testthat::test_dir("tests/testthat")'
```

## Roadmap

- [x] **Phase 1: Pipeline.** Catalog-driven download, DuckDB models, tests on a hand-calculated fixture
- [ ] **Phase 2: Dashboard.** State and facility tabs *(scaffolded)*; next: county map, weekend vs. weekday gap, contract-share trend, deploy to Posit Connect Cloud
- [ ] **Phase 3: Slack bot.** `/staffing` command *(stubbed)*; next: Block Kit layout, xlsx export, scheduled weekly digest
- [ ] **Phase 4: Validation.** Reconcile against CMS's published Provider Information staffing figures and document any differences
- [ ] **Phase 5: Write-up.** Findings, plus how I used Claude Code as a development partner

## About

Built by [Danielle Davis](https://www.linkedin.com/in/danielle-davis-560152142/). The patterns here (migrating BI dashboards to code, checking numbers against the source, server-side filtering for large dropdowns, Slack-delivered reports) come from my work as a BI developer in healthcare staffing.
