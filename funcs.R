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



plot_by_category <- function(data, my_title="This is a good title" ,
                             my_subtitle="this is a subtitle", n_rows=3, 
                             time_col="month", ts_col="roll_avg_round", colour_facet_group="Keyword",
                             si_accuracy=0.1, my_strip_title_size=1,my_caption=NULL,
                             my_font = "Segoe UI") 
{ 
  
  data %>% 
    ggplot(aes(x= .data[[time_col]], y= .data[[ts_col]], colour= .data[[colour_facet_group]])) +  
    geom_line(alpha = 0.9, size = 1.8) +
    geom_smooth(method = "lm", se = F, linetype=3,  alpha=0.3) +
    expand_limits(y = NULL) + 
    facet_wrap(~.data[[colour_facet_group]], scales = "free_y", nrow = n_rows, labeller = label_wrap_gen(width=20)) +
    scale_y_continuous(labels = scales::label_number(scale_cut = cut_short_scale())) +
    #scale_y_continuous(labels  = scales::comma_format()) +
    labs(title = my_title, subtitle = my_subtitle)  +
    ylab("Search volume by month - Google US \n") + xlab(label = NULL) +  #+ scale_color_wsj() a
    my_social_theme(strip_title_size = my_strip_title_size)
  
  
}

my_social_theme <- function (strip_title_size = 1, base_size = 12) 
{
  colors <- deframe(ggthemes::ggthemes_data[["fivethirtyeight"]])
  (theme_foundation(base_size = base_size) + 
      theme(line = element_line(colour = "black"), rect = element_rect(fill = colors["White"], 
                                                                       linetype = 0, colour = NA), text = element_text(colour = colors["Dark Gray"]), 
            axis.text = element_text(), axis.ticks = element_blank(), 
            axis.line = element_blank(), legend.background = element_rect(), 
            legend.position = "none", legend.direction = "horizontal", 
            legend.box = "vertical", panel.grid = element_line(colour = NULL), 
            panel.grid.major = element_line(colour = colors["Medium Gray"]), 
            panel.grid.minor = element_blank(), plot.title = element_text(hjust = 0, 
                                                                          size = rel(1.5), colour = "black", face = "bold"), 
            plot.margin = unit(c(1, 1, 1, 1), "lines"), strip.background = element_rect(fill = "white", 
                                                                                        colour = "black", size = 1), strip.text = element_text(size = rel(strip_title_size), 
                                                                                                                                               face = "bold"))) }
