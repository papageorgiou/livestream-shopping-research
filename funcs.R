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
