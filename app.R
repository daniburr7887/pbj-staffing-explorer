# PBJ Staffing Explorer: Shiny dashboard.
# Files in R/ are sourced automatically by Shiny.

library(shiny)
library(bslib)

con <- pbj_connect(read_only = TRUE)
onStop(function() DBI::dbDisconnect(con, shutdown = TRUE))

# Small tables are loaded once at startup; facility detail is queried on demand.
state_month <- DBI::dbGetQuery(con, "SELECT * FROM agg_state_month")
facilities <- DBI::dbGetQuery(con, "
  SELECT provnum, facility_name, city, state FROM dim_facility ORDER BY facility_name
")
months <- sort(unique(state_month$month), decreasing = TRUE)

fmt_hprd <- function(x) formatC(x, format = "f", digits = 2)
fmt_pct <- function(x) paste0(formatC(100 * x, format = "f", digits = 1), "%")

ui <- page_navbar(
  title = "PBJ Staffing Explorer",
  theme = bs_theme(version = 5),

  nav_panel(
    "States",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("state_month", "Month", choices = format(months, "%b %Y"))
      ),
      card(
        card_header("Nurse staffing by state"),
        DT::DTOutput("state_table")
      )
    )
  ),

  nav_panel(
    "Facility",
    layout_sidebar(
      sidebar = sidebar(
        # ~15k facilities: choices are sent from the server as the user
        # types, so the browser never renders a giant dropdown.
        selectizeInput("provnum", "Facility", choices = NULL,
                       options = list(placeholder = "Search by name or city"))
      ),
      layout_column_wrap(
        width = 1 / 3,
        value_box("Total nurse HPRD", textOutput("vb_total")),
        value_box("RN HPRD", textOutput("vb_rn")),
        value_box("Contract share of hours", textOutput("vb_ctr"))
      ),
      card(
        card_header("Monthly total nurse HPRD vs. state"),
        plotOutput("facility_trend")
      )
    )
  )
)

server <- function(input, output, session) {
  updateSelectizeInput(
    session, "provnum", server = TRUE,
    choices = setNames(
      facilities$provnum,
      paste0(facilities$facility_name, " (", facilities$city, ", ", facilities$state, ")")
    )
  )

  # ---- States tab ----
  output$state_table <- DT::renderDT({
    selected <- months[format(months, "%b %Y") == input$state_month]
    df <- add_ratios(state_month[state_month$month == selected, ])

    DT::datatable(
      data.frame(
        State = df$state,
        Facilities = df$facilities,
        `Total HPRD` = fmt_hprd(df$total_hprd),
        `RN HPRD` = fmt_hprd(df$rn_hprd),
        `Contract share` = fmt_pct(df$contract_share),
        check.names = FALSE
      ),
      rownames = FALSE,
      options = list(pageLength = 60, order = list(list(2, "desc")))
    )
  })

  # ---- Facility tab ----
  facility_months <- reactive({
    req(input$provnum)
    DBI::dbGetQuery(
      con,
      "SELECT m.*, f.state FROM fct_facility_month m
       JOIN dim_facility f USING (provnum)
       WHERE provnum = ? ORDER BY month",
      params = list(input$provnum)
    )
  })

  facility_totals <- reactive(summarise_staffing(facility_months(), provnum))

  output$vb_total <- renderText(fmt_hprd(facility_totals()$total_hprd))
  output$vb_rn <- renderText(fmt_hprd(facility_totals()$rn_hprd))
  output$vb_ctr <- renderText(fmt_pct(facility_totals()$contract_share))

  output$facility_trend <- renderPlot({
    fac <- summarise_staffing(facility_months(), month)
    st <- add_ratios(state_month[state_month$state == facility_months()$state[[1]], ])

    plot_df <- rbind(
      data.frame(month = fac$month, hprd = fac$total_hprd, series = "Facility"),
      data.frame(month = st$month, hprd = st$total_hprd, series = "State")
    )
    ggplot2::ggplot(plot_df, ggplot2::aes(month, hprd, colour = series)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_point() +
      ggplot2::labs(x = NULL, y = "Hours per resident day", colour = NULL) +
      ggplot2::theme_minimal(base_size = 14) +
      ggplot2::theme(legend.position = "top")
  })
}

shinyApp(ui, server)
