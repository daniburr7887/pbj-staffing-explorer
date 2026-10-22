# PBJ Staffing Explorer: Shiny dashboard.
# Files in R/ are sourced automatically by Shiny.

library(shiny)
library(bslib)

con <- pbj_app_connect()
onStop(function() DBI::dbDisconnect(con, shutdown = TRUE))

# Small tables are loaded once at startup; facility detail is queried on demand.
state_month <- DBI::dbGetQuery(con, "SELECT * FROM agg_state_month")
county_month <- DBI::dbGetQuery(con, "SELECT * FROM agg_county_month")
facilities <- DBI::dbGetQuery(con, "
  SELECT provnum, facility_name, city, state FROM dim_facility ORDER BY facility_name
")
shapes <- county_shapes()

months <- sort(unique(state_month$month), decreasing = TRUE)
period_choices <- c(
  setNames("all", paste0("All ", length(months), " months (", fmt_month(min(months)), " – ", fmt_month(max(months)), ")")),
  setNames(as.character(months), fmt_month(months))
)

# Keep only the months in the selected period.
in_period <- function(df, period) {
  if (identical(period, "all")) df else df[df$month == as.Date(period), ]
}

# Sum to one row per group, then compute ratios (see R/metrics.R).
roll_up <- function(df, by) {
  sums <- c("facilities", "resident_days", "hrs_rn", "hrs_total", "hrs_total_ctr",
            "weekend_resident_days", "weekend_hrs_total")
  out <- stats::aggregate(df[setdiff(sums, "facilities")], df[by], sum)
  # Facility counts can't be summed across months; take the monthly max.
  out$facilities <- stats::aggregate(df["facilities"], df[by], max)$facilities
  add_ratios(out)
}

kpi_box <- function(title, output_id, caption_id = NULL) {
  value_box(
    title = title,
    value = textOutput(output_id),
    if (!is.null(caption_id)) textOutput(caption_id),
    theme = value_box_theme(bg = PBJ_COLORS$surface, fg = PBJ_COLORS$ink)
  )
}

ui <- page_navbar(
  title = "PBJ Staffing Explorer",
  id = "nav",
  fillable = FALSE,  # let long tabs (e.g. Weekends) scroll instead of clipping
  theme = bs_theme(
    version = 5,
    bg = PBJ_COLORS$surface,
    fg = PBJ_COLORS$ink,
    primary = PBJ_COLORS$accent,
    base_font = font_collection("system-ui", "-apple-system", "Segoe UI", "sans-serif")
  ),
  header = tags$style(HTML(
    # Chart SVGs name the server's default sans font, which shinyapps.io
    # doesn't have, so browsers fell back to serif. Pin the UI sans instead.
    '.girafe svg text { font-family: system-ui, -apple-system, "Segoe UI", Arial, sans-serif !important; }'
  )),
  sidebar = sidebar(
    selectInput("period", "Period", choices = period_choices),
    conditionalPanel(
      "input.nav === 'Facility'",
      # ~15k facilities: choices are sent from the server as the user
      # types, so the browser never renders a giant dropdown.
      selectizeInput("provnum", "Facility", choices = NULL,
                     options = list(placeholder = "Search by name or city"))
    ),
    tags$small(
      class = "text-muted",
      "HPRD = nurse hours per resident day. Source: ",
      tags$a("CMS Payroll-Based Journal", href = "https://data.cms.gov/quality-of-care/payroll-based-journal-daily-nurse-staffing", target = "_blank"),
      "."
    )
  ),

  nav_panel(
    "Overview",
    layout_column_wrap(
      width = 1 / 4, fill = FALSE,
      kpi_box("Total nurse HPRD", "us_total"),
      kpi_box("RN HPRD", "us_rn"),
      kpi_box("Weekend vs. weekday HPRD", "us_gap", "us_gap_caption"),
      kpi_box("Contract share of hours", "us_ctr")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(card_header("National total nurse HPRD by month"), ggiraph::girafeOutput("us_hprd_trend", height = "auto")),
      card(card_header("National contract share of hours by month"), ggiraph::girafeOutput("us_ctr_trend", height = "auto"))
    )
  ),

  nav_panel(
    "States",
    layout_columns(
      col_widths = c(7, 5),
      card(
        full_screen = TRUE,
        card_header("Nurse staffing by state", tags$small(class = "text-muted ms-2", "Click a row to map its counties")),
        DT::DTOutput("state_table")
      ),
      card(
        full_screen = TRUE,
        card_header(textOutput("map_title", inline = TRUE)),
        uiOutput("county_map_ui")
      )
    )
  ),

  nav_panel(
    "Weekends",
    card(
      full_screen = TRUE,
      card_header(
        "Weekday vs. weekend staffing by state",
        tags$small(class = "text-muted ms-2", "Sorted by the size of the weekend drop")
      ),
      ggiraph::girafeOutput("weekend_chart", height = "auto")
    )
  ),

  nav_panel(
    "Facility",
    layout_column_wrap(
      width = 1 / 4, fill = FALSE,
      kpi_box("Total nurse HPRD", "fac_total", "fac_total_caption"),
      kpi_box("RN HPRD", "fac_rn"),
      kpi_box("Weekend HPRD", "fac_weekend", "fac_weekend_caption"),
      kpi_box("Contract share of hours", "fac_ctr", "fac_ctr_caption")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(card_header("Monthly total nurse HPRD vs. state"), ggiraph::girafeOutput("fac_hprd_trend", height = "auto")),
      card(card_header("Monthly contract share vs. state"), ggiraph::girafeOutput("fac_ctr_trend", height = "auto"))
    )
  )
)

server <- function(input, output, session) {
  # Deep links: ?tab=Weekends opens a tab, ?facility=<CCN> opens a facility.
  query <- isolate(parseQueryString(session$clientData$url_search))
  linked_facility <- if (!is.null(query$facility) && query$facility %in% facilities$provnum) query$facility

  updateSelectizeInput(
    session, "provnum", server = TRUE,
    choices = setNames(
      facilities$provnum,
      paste0(facilities$facility_name, " (", facilities$city, ", ", facilities$state, ")")
    ),
    selected = linked_facility
  )
  if (!is.null(linked_facility)) {
    nav_select("nav", "Facility")
  } else if (!is.null(query$tab)) {
    nav_select("nav", query$tab)
  }

  states_in_period <- reactive(roll_up(in_period(state_month, input$period), "state"))

  # ---- Overview tab ----
  national <- reactive({
    df <- in_period(state_month, input$period)
    df$nation <- "US"
    roll_up(df, "nation")
  })
  national_by_month <- roll_up(transform(state_month, nation = "US"), c("nation", "month"))

  output$us_total <- renderText(fmt_hprd(national()$total_hprd))
  output$us_rn <- renderText(fmt_hprd(national()$rn_hprd))
  output$us_ctr <- renderText(fmt_pct(national()$contract_share))
  output$us_gap <- renderText(sub("-", "\u2212", sprintf("%+.2f", national()$weekend_hprd - national()$weekday_hprd)))
  output$us_gap_caption <- renderText(paste0(
    fmt_hprd(national()$weekend_hprd), " weekends vs. ", fmt_hprd(national()$weekday_hprd), " weekdays"
  ))

  output$us_hprd_trend <- ggiraph::renderGirafe(
    trend_chart(national_by_month, "total_hprd", "Total HPRD", fmt_hprd, "Hours per resident day")
  )
  output$us_ctr_trend <- ggiraph::renderGirafe(
    trend_chart(national_by_month, "contract_share", "Contract share", fmt_pct, "Share of nurse hours")
  )

  # ---- States tab ----
  # Remember the selected state across period changes. Default to the
  # state with the most facilities so the map isn't empty on first load.
  selected_state <- reactiveVal(
    state_month$state[which.max(state_month$facilities)]
  )

  state_table_data <- reactive(states_in_period())

  output$state_table <- DT::renderDT({
    df <- state_table_data()
    # Keep columns numeric and format in DT, so sorting is numeric
    # (formatted strings would sort "12.7%" before "2.2%").
    DT::datatable(
      data.frame(
        State = df$state,
        Facilities = df$facilities,
        `Total HPRD` = df$total_hprd,
        `RN HPRD` = df$rn_hprd,
        `Weekend gap` = df$weekend_hprd - df$weekday_hprd,
        `Contract share` = df$contract_share,
        check.names = FALSE
      ),
      rownames = FALSE,
      selection = list(mode = "single", target = "row", selected = match(isolate(selected_state()), df$state)),
      options = list(pageLength = 60, order = list(list(2, "desc")), dom = "ft", scrollY = "520px", scrollCollapse = TRUE)
    ) |>
      DT::formatRound(c("Total HPRD", "RN HPRD", "Weekend gap"), digits = 2) |>
      DT::formatPercentage("Contract share", digits = 1)
  })

  observeEvent(input$state_table_rows_selected, {
    selected_state(state_table_data()$state[input$state_table_rows_selected])
  })

  output$map_title <- renderText(paste0(selected_state(), " counties: total nurse HPRD"))

  output$county_map_ui <- renderUI({
    st <- selected_state()
    if (st %in% names(STATES_WITHOUT_OUTLINES)) {
      return(p(class = "text-muted p-3", STATES_WITHOUT_OUTLINES[[st]], " The state table still includes it."))
    }
    tagList(
      ggiraph::girafeOutput("county_map", height = "auto"),
      tags$small(class = "text-muted", textOutput("map_caption", inline = TRUE))
    )
  })

  counties_in_period <- reactive({
    df <- in_period(county_month, input$period)
    df <- df[df$state == selected_state(), ]
    out <- roll_up(df, c("state", "county_code"))
    out$county_name <- df$county_name[match(out$county_code, df$county_code)]
    out
  })

  output$county_map <- ggiraph::renderGirafe({
    st <- selected_state()
    req(!st %in% names(STATES_WITHOUT_OUTLINES))
    county_map_chart(shapes[shapes$state == st, ], counties_in_period())
  })

  output$map_caption <- renderText({
    drawn <- unique(shapes$county_code[shapes$state == selected_state()])
    missing <- counties_in_period()[!counties_in_period()$county_code %in% drawn, ]
    if (nrow(missing) == 0) return("Gray: no PBJ-reporting facilities.")
    paste0(
      "Gray: no PBJ-reporting facilities. Not drawn (no outline available): ",
      paste(missing$county_name, collapse = ", "), "."
    )
  })

  # ---- Weekends tab ----
  output$weekend_chart <- ggiraph::renderGirafe(weekend_dumbbell_chart(states_in_period()))

  # ---- Facility tab ----
  facility_months <- reactive({
    validate(need(input$provnum, "Search for a facility in the sidebar to see its staffing."))
    DBI::dbGetQuery(
      con,
      "SELECT m.*, f.state FROM fct_facility_month m
       JOIN dim_facility f USING (provnum)
       WHERE provnum = ? ORDER BY month",
      params = list(input$provnum)
    )
  })

  facility_state <- reactive(facility_months()$state[[1]])

  facility_period <- reactive({
    df <- in_period(facility_months(), input$period)
    validate(need(nrow(df) > 0, "This facility reported no staffing in the selected period."))
    summarise_staffing(df, provnum)
  })

  state_period <- reactive(states_in_period()[states_in_period()$state == facility_state(), ])

  vs_state <- function(state_value, fmt) paste0(facility_state(), " average: ", fmt(state_value))

  output$fac_total <- renderText(fmt_hprd(facility_period()$total_hprd))
  output$fac_total_caption <- renderText(vs_state(state_period()$total_hprd, fmt_hprd))
  output$fac_rn <- renderText(fmt_hprd(facility_period()$rn_hprd))
  output$fac_weekend <- renderText(fmt_hprd(facility_period()$weekend_hprd))
  output$fac_weekend_caption <- renderText(paste0("Weekdays: ", fmt_hprd(facility_period()$weekday_hprd)))
  output$fac_ctr <- renderText(fmt_pct(facility_period()$contract_share))
  output$fac_ctr_caption <- renderText(vs_state(state_period()$contract_share, fmt_pct))

  facility_trend_data <- reactive(list(
    fac = summarise_staffing(facility_months(), month),
    st = add_ratios(state_month[state_month$state == facility_state(), ])
  ))

  output$fac_hprd_trend <- ggiraph::renderGirafe({
    d <- facility_trend_data()
    facility_vs_state_chart(d$fac, d$st, "total_hprd", fmt_hprd, "Hours per resident day")
  })
  output$fac_ctr_trend <- ggiraph::renderGirafe({
    d <- facility_trend_data()
    facility_vs_state_chart(d$fac, d$st, "contract_share", fmt_pct, "Share of nurse hours")
  })
}

shinyApp(ui, server)
