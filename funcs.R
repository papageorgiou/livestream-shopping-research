# Save a ggplot as a high-res raster (PNG or TIFF) for reports
save_for_report <- function(
  p = ggplot2::last_plot(),
  filename,
  width_mm = 172,
  height_mm = 100,
  dpi = 600,
  bg = "white",
  compression = "lzw"   # used for TIFF
) {
  stopifnot(
    is.character(filename), 
    length(filename) == 1
  )
  
  ext <- tolower(tools::file_ext(filename))
  
  dev <- switch(
    ext,
    "png" = ragg::agg_png,
    "tif" = ragg::agg_tiff,
    "tiff" = ragg::agg_tiff,
    stop(
      'Filename must end with .png, .tif, or .tiff', 
      call. = FALSE
    )
  )
  
  args <- list(
    filename = filename,
    plot = p,
    device = dev,
    width = width_mm,
    height = height_mm,
    units = "mm",
    dpi = dpi,
    bg = bg
  )
  
  if (ext %in% c("tif", "tiff")) {
    args$compression <- compression
  }
  
  do.call(ggplot2::ggsave, args)
  invisible(normalizePath(filename))
}

# Prepare monthly totals for a given keyword pattern
prepare_monthly_totals <- function(
  dataset,
  keyword_pattern,
  filter_out,
  start_month,
  months = 48
) {
  stopifnot(
    is.character(keyword_pattern), length(keyword_pattern) == 1,
    is.character(start_month), length(start_month) == 1,
    is.numeric(months), length(months) == 1
  )

  filtered <- dataset %>%
    dplyr::filter(stringr::str_detect(keyword, keyword_pattern)) %>%
    dplyr::filter(lengths(searches_past_months) > 0) %>%
    dplyr::arrange(dplyr::desc(avg_monthly_searches)) %>%
    dplyr::filter(avg_monthly_searches > 0) %>%
    dplyr::filter(!keyword %in% filter_out)

  long <- filtered %>%
    tidyr::unnest_longer(searches_past_months) %>%
    dplyr::ungroup()

  month_sequence <- seq(lubridate::ymd(start_month), by = "month", length.out = months)

  all_by_month <- long %>%
    dplyr::mutate(month = rep(month_sequence, length.out = nrow(long)))

  grouped <- all_by_month %>%
    dplyr::group_by(month) %>%
    dplyr::summarise(total_monthly_searches = sum(searches_past_months), .groups = "drop") %>%
    dplyr::mutate(
      month_label = format(month, "%m-%Y"),
      month_end = lubridate::ceiling_date(month, "month") - lubridate::days(1)
    )

  grouped
}

# Compute index values (first row as base by default)
compute_index <- function(
  grouped_df,
  value_col = "total_monthly_searches",
  base_row = 1,
  base_index = 100
) {
  stopifnot(is.data.frame(grouped_df))
  stopifnot(value_col %in% names(grouped_df))
  stopifnot(base_row >= 1, base_row <= nrow(grouped_df))

  base_value <- grouped_df[[value_col]][base_row]
  col_sym <- rlang::sym(value_col)

  dplyr::mutate(
    grouped_df,
    index_value = (!!col_sym / base_value) * base_index
  )
}
