# Chart builders for the dashboard. Each returns an interactive ggiraph
# object with hover tooltips.
#
# Palette (validated with the dataviz palette checker):
#   emphasis   #2a78d6 blue for the subject, #898781 gray for context
#   dumbbell   #86b6ef weekday / #1c5cab weekend (one hue, two steps)
#   map        sequential blue #cde2fb -> #0d366b, #f0efec for no data

PBJ_COLORS <- list(
  surface = "#fcfcfb",
  ink = "#0b0b0b",
  ink_secondary = "#52514e",
  muted = "#898781",
  grid = "#e1e0d9",
  no_data = "#f0efec",
  accent = "#2a78d6",
  weekday = "#86b6ef",
  weekend = "#1c5cab",
  seq_low = "#cde2fb",
  seq_high = "#0d366b"
)

theme_pbj <- function() {
  ggplot2::theme_minimal(base_size = 13, base_family = "") +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = PBJ_COLORS$surface, colour = NA),
      panel.grid.major = ggplot2::element_line(colour = PBJ_COLORS$grid, linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = PBJ_COLORS$muted),
      axis.title = ggplot2::element_text(colour = PBJ_COLORS$ink_secondary),
      legend.text = ggplot2::element_text(colour = PBJ_COLORS$ink_secondary),
      legend.position = "top",
      legend.justification = "left",
      # Extra right margin: the browser's sans font is wider than the server's
      # text metrics, so the last axis label would otherwise clip.
      plot.margin = ggplot2::margin(5.5, 24, 5.5, 5.5)
    )
}

# width/height are in inches at 96 dpi; keep them close to the card's real
# size so text renders near its true size instead of being scaled down.
pbj_girafe <- function(plot, width = 7.5, height = 3.8) {
  ggiraph::girafe(
    ggobj = plot,
    width_svg = width,
    height_svg = height,
    options = list(
      ggiraph::opts_tooltip(
        css = paste0(
          "background:", PBJ_COLORS$ink, ";color:#f0efec;padding:6px 8px;",
          "border-radius:4px;font-family:system-ui,sans-serif;font-size:13px;line-height:1.4;"
        ),
        use_fill = FALSE
      ),
      ggiraph::opts_hover(css = "stroke:#0b0b0b;stroke-width:1.5px;"),
      ggiraph::opts_hover_inv(css = "opacity:0.45;"),
      ggiraph::opts_toolbar(saveaspng = FALSE),
      ggiraph::opts_sizing(rescale = TRUE)
    )
  )
}

fmt_hprd <- function(x) formatC(x, format = "f", digits = 2)
fmt_pct <- function(x) paste0(formatC(100 * x, format = "f", digits = 1), "%")
fmt_month <- function(x) format(x, "%b %Y")

# A single monthly trend line (national overview).
trend_chart <- function(df, value, label, fmt, y_label) {
  df$tooltip <- paste0(fmt_month(df$month), "<br>", label, ": <b>", fmt(df[[value]]), "</b>")
  p <- ggplot2::ggplot(df, ggplot2::aes(month, .data[[value]])) +
    ggplot2::geom_line(colour = PBJ_COLORS$accent, linewidth = 0.8) +
    ggiraph::geom_point_interactive(
      ggplot2::aes(tooltip = tooltip, data_id = as.character(month)),
      colour = PBJ_COLORS$accent, fill = PBJ_COLORS$surface, shape = 21, size = 3, stroke = 1.2
    ) +
    ggplot2::scale_x_date(date_labels = "%b %Y") +
    ggplot2::labs(x = NULL, y = y_label) +
    theme_pbj()
  if (identical(fmt, fmt_pct)) {
    p <- p + ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x, 1), "%"))
  }
  pbj_girafe(p)
}

# Facility (accent) against its state (gray context), with end-of-line labels.
facility_vs_state_chart <- function(fac, st, value, fmt, y_label) {
  df <- rbind(
    data.frame(month = st$month, value = st[[value]], series = "State"),
    data.frame(month = fac$month, value = fac[[value]], series = "Facility")
  )
  df$series <- factor(df$series, levels = c("Facility", "State"))
  df$tooltip <- paste0(df$series, " · ", fmt_month(df$month), "<br><b>", fmt(df$value), "</b>")
  ends <- do.call(rbind, lapply(split(df, df$series), function(d) d[which.max(d$month), ]))

  p <- ggplot2::ggplot(df, ggplot2::aes(month, value, colour = series)) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggiraph::geom_point_interactive(
      ggplot2::aes(tooltip = tooltip, data_id = paste(series, month)),
      fill = PBJ_COLORS$surface, shape = 21, size = 3, stroke = 1.2
    ) +
    ggplot2::geom_text(
      data = ends, ggplot2::aes(label = series), colour = PBJ_COLORS$ink_secondary,
      hjust = 0, nudge_x = 8, size = 3.8, show.legend = FALSE
    ) +
    ggplot2::scale_colour_manual(values = c(Facility = PBJ_COLORS$accent, State = PBJ_COLORS$muted), name = NULL) +
    ggplot2::scale_x_date(date_labels = "%b %Y", expand = ggplot2::expansion(mult = c(0.02, 0.1))) +
    ggplot2::labs(x = NULL, y = y_label) +
    theme_pbj()
  if (identical(fmt, fmt_pct)) {
    p <- p + ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x, 1), "%"))
  }
  pbj_girafe(p)
}

# Weekday vs weekend HPRD per state, sorted by the size of the weekend drop.
weekend_dumbbell_chart <- function(states) {
  states <- states[!is.na(states$weekend_hprd), ]
  states$gap <- states$weekend_hprd - states$weekday_hprd
  states$state <- factor(states$state, levels = states$state[order(states$gap, decreasing = TRUE)])
  states$tooltip <- paste0(
    "<b>", states$state, "</b><br>",
    "Weekday: ", fmt_hprd(states$weekday_hprd), "<br>",
    "Weekend: ", fmt_hprd(states$weekend_hprd), "<br>",
    "Gap: ", sprintf("%+.2f", states$gap)
  )
  points <- rbind(
    data.frame(state = states$state, hprd = states$weekday_hprd, day = "Weekday", tooltip = states$tooltip),
    data.frame(state = states$state, hprd = states$weekend_hprd, day = "Weekend", tooltip = states$tooltip)
  )
  # Direct labels on the top row (the largest gap) so the legend isn't the only key.
  top <- points[points$state == levels(states$state)[nlevels(states$state)], ]

  p <- ggplot2::ggplot(states, ggplot2::aes(y = state)) +
    ggiraph::geom_segment_interactive(
      ggplot2::aes(x = weekend_hprd, xend = weekday_hprd, yend = state, tooltip = tooltip, data_id = state),
      colour = PBJ_COLORS$grid, linewidth = 1.6
    ) +
    ggiraph::geom_point_interactive(
      data = points, ggplot2::aes(x = hprd, colour = day, tooltip = tooltip, data_id = state),
      size = 3
    ) +
    ggplot2::geom_text(
      data = top, ggplot2::aes(x = hprd, label = day), colour = PBJ_COLORS$ink_secondary,
      vjust = -1, size = 3.5
    ) +
    ggplot2::scale_colour_manual(values = c(Weekday = PBJ_COLORS$weekday, Weekend = PBJ_COLORS$weekend), name = NULL) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = c(0.6, 1.2))) +
    ggplot2::labs(x = "Total nurse hours per resident day", y = NULL) +
    theme_pbj() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = PBJ_COLORS$grid, linewidth = 0.3)
    )
  pbj_girafe(p, width = 12, height = 12)
}

# County choropleth of total HPRD for one state.
county_map_chart <- function(shapes, counties) {
  df <- merge(shapes, counties, by = c("state", "county_code"), all.x = TRUE, sort = FALSE)
  df <- df[order(df$group, df$order), ]
  df$tooltip <- ifelse(
    is.na(df$total_hprd),
    paste0("<b>", tools::toTitleCase(df$subregion), "</b><br>No PBJ-reporting facilities"),
    paste0(
      "<b>", df$county_name, "</b><br>",
      "Total HPRD: ", fmt_hprd(df$total_hprd), "<br>",
      "Contract share: ", fmt_pct(df$contract_share), "<br>",
      df$facilities, ifelse(df$facilities == 1, " facility", " facilities")
    )
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(long, lat, group = group)) +
    ggiraph::geom_polygon_interactive(
      ggplot2::aes(fill = total_hprd, tooltip = tooltip, data_id = county_code),
      colour = PBJ_COLORS$surface, linewidth = 0.2
    ) +
    ggplot2::scale_fill_gradient(
      low = PBJ_COLORS$seq_low, high = PBJ_COLORS$seq_high,
      na.value = PBJ_COLORS$no_data, name = "Total HPRD",
      guide = ggplot2::guide_colourbar(barwidth = grid::unit(16, "lines"), barheight = grid::unit(0.8, "lines"))
    ) +
    ggplot2::coord_quickmap() +
    ggplot2::theme_void(base_size = 13) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = PBJ_COLORS$surface, colour = NA),
      legend.position = "top",
      legend.justification = "left",
      legend.text = ggplot2::element_text(colour = PBJ_COLORS$ink_secondary),
      legend.title = ggplot2::element_text(colour = PBJ_COLORS$ink_secondary)
    )
  pbj_girafe(p, width = 6, height = 5)
}
