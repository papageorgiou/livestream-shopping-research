# Shared plotting theme + helpers for the 2026 Live Shopping report.
# Adapted from the project's gg-functions.R / funcs.R (FiveThirtyEight base).

suppressPackageStartupMessages({
  library(tidyverse)
  library(ggthemes)
  library(ggtext)
  library(scales)
  library(ggrepel)
  library(patchwork)
  library(lubridate)
})

# brand palette (mirrors report-2026/_brand.yml)
LS_COL <- list(
  red      = "#CD0000",
  reddark  = "#A30000",
  yellow   = "#F2C200",
  whatnot  = "#FFF351",
  ink      = "#3C3C3C",
  graymid  = "#B0B0B0",
  graylight= "#EDEDED",
  paper    = "#FFFFFF"
)

# categorical palette for multi-series charts
LS_CATEGORICAL <- c(
  "#CD0000", "#1F77B4", "#2CA02C", "#FF7F0E", "#9467BD",
  "#8C564B", "#E377C2", "#17BECF", "#BCBD22", "#7F7F7F",
  "#393B79", "#637939", "#8C6D31", "#843C39"
)

theme_ls <- function(base_size = 22, base_family = "Helvetica Neue") {
  ggthemes::theme_foundation(base_size = base_size, base_family = base_family) +
    theme(
      line = element_line(colour = LS_COL$ink),
      rect = element_rect(fill = LS_COL$paper, linetype = 0, colour = NA),
      text = element_text(colour = LS_COL$ink),
      axis.text = element_text(colour = LS_COL$ink),
      axis.ticks = element_blank(),
      axis.line = element_blank(),
      legend.position = "none",
      panel.grid.major = element_line(colour = LS_COL$graymid, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      # textbox variants wrap long titles/captions instead of clipping them,
      # which matters at the larger base_size used for the report figures.
      plot.title = ggtext::element_textbox_simple(
        hjust = 0, size = rel(1.35), face = "bold", colour = LS_COL$ink,
        lineheight = 1.1, width = grid::unit(1, "npc"), margin = margin(b = 4)),
      plot.subtitle = ggtext::element_textbox_simple(
        hjust = 0, size = rel(1.0), colour = LS_COL$ink,
        lineheight = 1.15, width = grid::unit(1, "npc"), margin = margin(b = 6)),
      plot.caption = ggtext::element_textbox_simple(
        hjust = 0, size = rel(0.75), face = "italic", colour = LS_COL$graymid,
        lineheight = 1.1, width = grid::unit(1, "npc"), margin = margin(t = 8)),
      plot.caption.position = "plot",
      plot.title.position = "plot",
      strip.background = element_rect(fill = "white", colour = LS_COL$ink, linewidth = 0.6),
      strip.text = element_text(face = "bold", size = rel(0.9)),
      plot.margin = margin(10, 12, 8, 10)
    )
}

# faceted multi-keyword time-series (mirrors plot_by_category)
plot_by_category <- function(data, title, subtitle = NULL, caption = NULL,
                             n_rows = 3, time_col = "month", ts_col = "roll_avg",
                             group_col = "keyword") {
  data %>%
    ggplot(aes(x = .data[[time_col]], y = .data[[ts_col]], colour = .data[[group_col]])) +
    geom_line(linewidth = 1.1, alpha = 0.9) +
    geom_smooth(method = "lm", se = FALSE, linetype = 3, linewidth = 0.5) +
    facet_wrap(~.data[[group_col]], scales = "free_y", nrow = n_rows,
               labeller = label_wrap_gen(width = 18)) +
    scale_y_continuous(labels = scales::comma_format()) +
    scale_colour_manual(values = rep(LS_CATEGORICAL, 4)) +
    labs(title = title, subtitle = subtitle, caption = caption,
         x = NULL, y = "Monthly US search interest") +
    theme_ls()
}

# standard caption for index charts (wrapped to avoid horizontal clipping)
ls_source_caption <- function(window_label) {
  stringr::str_wrap(paste0(
    "Source: Google Ads Keyword Planner API (US, English), ", window_label,
    ". Data retrieved June 2026. Index = normalized U.S. search volume, first month = 100."
  ), width = 95)
}
