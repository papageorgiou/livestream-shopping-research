# Generate all publication-quality figures for the 2026 Live Shopping report.
# Run:  Rscript report-2026/R/make_charts.R
# Reads report-2026/data/*.csv, writes report-2026/figures/*.png

here <- "/Users/alexp/gd_alpapag/apclients/livestream-shopping-research/report-2026"
source(file.path(here, "R/theme.R"))
fig_dir  <- file.path(here, "figures")
data_dir <- file.path(here, "data")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

save_fig <- function(p, name, w = 240, h = 135, dpi = 300) {
  ragg::agg_png(file.path(fig_dir, name), width = w, height = h,
                units = "mm", res = dpi, background = "white")
  print(p); invisible(dev.off())
}

roll3 <- function(x) zoo::rollmean(x, 3, fill = NA, align = "right")
WINDOW <- "June 2022 - May 2026"

# ── 1. Headline Live Shopping index (annotated) ─────────────────────────────
ls <- readr::read_csv(file.path(data_dir, "ls_index.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month), roll = zoo::rollmean(index_value, 3, fill = NA, align = "right"))

events <- tibble::tribble(
  ~date,         ~lab,                                  ~y,
  "2023-09-01",  "Sep '23\nTikTok Shop\nlaunches (US)", 140,
  "2024-12-01",  "Q4 '24\ninflection\nbegins",          150,
  "2025-01-01",  "Jan '25\nUS TikTok\nban drama",       120,
  "2025-04-01",  "Apr '25\nQVC 24/7 on\nTikTok",        172,
  "2026-01-01",  "Jan '26\nTikTok US deal\ncloses",     172
) |> mutate(date = as.Date(date))

trough <- ls |> slice_min(index_value, n = 1)

p1 <- ggplot(ls, aes(month, index_value)) +
  annotate("rect", xmin = as.Date("2024-04-01"), xmax = as.Date("2024-09-01"),
           ymin = -Inf, ymax = Inf, fill = LS_COL$graylight, alpha = 0.6) +
  geom_line(colour = LS_COL$graymid, linewidth = 0.5) +
  geom_point(colour = LS_COL$graymid, size = 0.8) +
  geom_line(aes(y = roll), colour = LS_COL$red, linewidth = 1.5) +
  geom_vline(data = events, aes(xintercept = date), linetype = 3,
             colour = LS_COL$ink, alpha = 0.5) +
  ggrepel::geom_text_repel(data = events, aes(x = date, y = y, label = lab),
                           inherit.aes = FALSE, size = 6, lineheight = 0.9,
                           colour = LS_COL$ink, segment.colour = LS_COL$graymid,
                           box.padding = 0.6, min.segment.length = 0, seed = 1) +
  annotate("text", x = trough$month, y = trough$index_value - 14,
           label = "Mid-2024 trough", size = 6, colour = LS_COL$ink, fontface = "italic") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %y") +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "US <span style='color:#CD0000;'>live shopping</span> search interest: from post-Meta slump to a 2025 breakout",
       subtitle = "Search-interest index (June 2022 = 100), 3-month moving average. Thin line = monthly values.",
       caption = ls_source_caption(WINDOW),
       x = NULL, y = "Index (June 2022 = 100)") +
  theme_ls()
save_fig(p1, "fig_ls_index.png", h = 140)

# ── 2. Live selling index (seller-side) ─────────────────────────────────────
sell <- readr::read_csv(file.path(data_dir, "live_sell_index.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month), roll = zoo::rollmean(index_value, 3, fill = NA, align = "right"))
last_sell <- round(tail(sell$roll[!is.na(sell$roll)], 1))

p2 <- ggplot(sell, aes(month, index_value)) +
  geom_line(colour = LS_COL$graymid, linewidth = 0.5) +
  geom_line(aes(y = roll), colour = "#1F77B4", linewidth = 1.5) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %y") +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "The supply side runs hotter: <span style='color:#1F77B4;'>live <b>selling</b></span> interest has more than doubled",
       subtitle = "Seller-oriented query index (June 2022 = 100), 3-month moving average. Sellers lead the category.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Index (June 2022 = 100)") +
  theme_ls()
save_fig(p2, "fig_live_sell.png", h = 130)

# ── 3. Platform landscape (LS-contextual search) ────────────────────────────
plat <- readr::read_csv(file.path(data_dir, "platform_index.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month))
keep_plat <- c("TikTok", "Whatnot", "QVC/HSN", "Facebook", "Instagram", "eBay")
plat2 <- plat |> filter(platform %in% keep_plat) |>
  group_by(platform) |> arrange(month) |>
  mutate(roll = zoo::rollmean(searches, 3, fill = NA, align = "right")) |> ungroup() |>
  mutate(platform = factor(platform, levels = keep_plat))

p3 <- ggplot(plat2, aes(month, roll, colour = platform)) +
  geom_line(linewidth = 1.2) +
  facet_wrap(~platform, nrow = 2, scales = "free_y") +
  scale_x_date(date_breaks = "1 year", date_labels = "%y") +
  scale_colour_manual(values = c(TikTok = LS_COL$ink, Whatnot = "#E0A800",
                                 `QVC/HSN` = LS_COL$red, Facebook = "#1F77B4",
                                 Instagram = "#9467BD", eBay = "#2CA02C")) +
  labs(title = "Platform rotation in live-shopping search: <span style='color:#E0A800;'>Whatnot</span> and <span style='color:#CD0000;'>QVC/HSN</span> rise as Meta fades",
       subtitle = "Monthly US search interest in '[platform] live shopping'-type queries, 3-month moving average.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Monthly searches") +
  theme_ls()
save_fig(p3, "fig_platform.png", h = 150)

# ── 4. Whatnot: brand search + GMV ──────────────────────────────────────────
wn <- readr::read_csv(file.path(data_dir, "whatnot_terms.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month)) |> filter(keyword == "whatnot")

p4a <- ggplot(wn, aes(month, roll_avg)) +
  geom_area(fill = LS_COL$whatnot, alpha = 0.5) +
  geom_line(colour = "#C9A800", linewidth = 1.5) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %y") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Brand search for <span style='background-color:#FFF351;'>&nbsp;Whatnot&nbsp;</span> has grown ~7x in three years",
       subtitle = "US monthly searches for \"whatnot\", 3-month moving average.",
       x = NULL, y = "Monthly searches") +
  theme_ls()

gmv <- tibble::tribble(
  ~year, ~gmv,
  2020, 0.1, 2021, 0.3, 2022, 1.0, 2023, 1.5, 2024, 3.0, 2025, 6.0
) |> mutate(date = as.Date(paste0(year, "-01-01")))

p4b <- ggplot(gmv, aes(date, gmv)) +
  geom_col(fill = LS_COL$whatnot, colour = "#C9A800", width = 250) +
  geom_text(aes(label = paste0("$", gmv, "B")), vjust = -0.5, size = 6, colour = LS_COL$ink) +
  scale_y_continuous(labels = scales::dollar_format(suffix = "B"), expand = expansion(c(0, 0.15))) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(title = "Whatnot gross merchandise value (GMV)",
       subtitle = "Estimated annual GMV from public reporting. 2025 ~ $6B+ ($8B live GMV cited); valued at $11.5B (Oct 2025).",
       caption = "Whatnot GMV are estimates from public announcements. Search: Google Ads Keyword Planner API.",
       x = NULL, y = NULL) +
  theme_ls()

p4 <- p4a / p4b + plot_layout(heights = c(1.4, 1))
save_fig(p4, "fig_whatnot.png", h = 190)

# ── 5. Emerging challengers ─────────────────────────────────────────────────
em <- readr::read_csv(file.path(data_dir, "emerging_terms.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month))
em_keep <- c("fanatics live", "ebay live", "palmstreet", "ntwrk")
em_lab <- c("fanatics live" = "Fanatics Live", "ebay live" = "eBay Live",
            "palmstreet" = "Palmstreet", "ntwrk" = "NTWRK")
em2 <- em |> filter(keyword %in% em_keep) |>
  group_by(keyword) |> arrange(month) |>
  mutate(roll = zoo::rollmean(roll_avg, 3, fill = NA, align = "right")) |> ungroup() |>
  mutate(keyword = factor(em_lab[keyword], levels = unname(em_lab)))

p5 <- ggplot(em2, aes(month, roll_avg, colour = keyword)) +
  geom_line(linewidth = 1.3) +
  facet_wrap(~keyword, nrow = 2, scales = "free_y", labeller = label_wrap_gen(20)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%y") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(values = LS_CATEGORICAL) +
  labs(title = "Beyond Whatnot: a wave of <span style='color:#CD0000;'>category-native</span> live-shopping challengers",
       subtitle = "US monthly search interest, 3-month moving average. Fanatics Live, eBay Live and Palmstreet climb; NTWRK's drop-hype fades.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Monthly searches") +
  theme_ls()
save_fig(p5, "fig_emerging.png", h = 150)

# ── 6. Top growers lollipop ─────────────────────────────────────────────────
tg <- readr::read_csv(file.path(data_dir, "top_growers.csv"), show_col_types = FALSE) |>
  slice_max(slope, n = 18) |> arrange(slope) |>
  mutate(keyword = factor(keyword, levels = keyword),
         theme = case_when(
           grepl("legit|safe|scam", keyword) ~ "Trust",
           grepl("whatnot", keyword) ~ "Whatnot",
           grepl("tiktok", keyword) ~ "TikTok Shop",
           grepl("fanatics|ebay|stockx|palmstreet|ntwrk", keyword) ~ "Challengers",
           TRUE ~ "Other"))

p6 <- ggplot(tg, aes(slope, keyword, colour = theme)) +
  geom_segment(aes(x = 0, xend = slope, yend = keyword), linewidth = 0.8) +
  geom_point(size = 3) +
  scale_x_continuous(labels = scales::comma, expand = expansion(c(0, 0.08))) +
  scale_colour_manual(values = c(Whatnot = "#C9A800", `TikTok Shop` = LS_COL$ink,
                                 Challengers = "#2CA02C", Trust = LS_COL$red, Other = LS_COL$graymid)) +
  labs(title = "Fastest-growing live-shopping queries are about <span style='color:#C9A800;'>Whatnot</span>, <span style='color:#2CA02C;'>challengers</span>, selling & <span style='color:#CD0000;'>trust</span>",
       subtitle = "Monthly-search growth slope (linear trend on 3-mo avg), live-shopping-relevant queries.",
       caption = ls_source_caption(WINDOW), x = "Growth (added monthly searches per month)", y = NULL) +
  theme_ls() + theme(legend.position = "top", legend.title = element_blank(),
                     panel.grid.major.y = element_blank())
save_fig(p6, "fig_growers.png", h = 150)

# ── 7. Trust queries ────────────────────────────────────────────────────────
tr <- readr::read_csv(file.path(data_dir, "trust_terms.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month)) |>
  group_by(keyword) |> arrange(month) |>
  mutate(roll = zoo::rollmean(roll_avg, 3, fill = NA, align = "right")) |> ungroup()

p7 <- ggplot(tr, aes(month, roll_avg, colour = keyword)) +
  geom_line(linewidth = 1.3) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(values = c("is whatnot legit" = "#C9A800",
                                 "is whatnot app legit" = "#E377C2",
                                 "is tiktok shop legit" = LS_COL$ink)) +
  labs(title = "Trust is the gating question: \"is it <span style='color:#CD0000;'>legit</span>?\" searches climb with adoption",
       subtitle = "US monthly searches for legitimacy queries, 3-month moving average. Inline labels at right.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Monthly searches") +
  theme_ls() +
  ggrepel::geom_text_repel(
    data = tr |> group_by(keyword) |> slice_max(month, n = 1),
    aes(label = keyword), nudge_x = 60, hjust = 0, direction = "y", size = 5.6,
    segment.colour = NA) +
  coord_cartesian(clip = "off") +
  theme(plot.margin = margin(10, 90, 8, 10))
save_fig(p7, "fig_trust.png", h = 130)

# ── 8. Seasonality (avg index by calendar month) ───────────────────────────
seas <- ls |>
  mutate(mn = lubridate::month(month), m = lubridate::month(month, label = TRUE)) |>
  group_by(mn, m) |> summarise(idx = mean(index_value), .groups = "drop") |> arrange(mn) |>
  mutate(q4 = mn %in% c(10, 11, 12), jan = mn == 1)

p8 <- ggplot(seas, aes(reorder(m, mn), idx, fill = q4)) +
  geom_col(width = 0.72) +
  geom_hline(yintercept = 100, linetype = 2, colour = LS_COL$graymid) +
  geom_text(aes(label = round(idx)), vjust = -0.5, size = 6, colour = LS_COL$ink) +
  annotate("text", x = "Jul", y = 138, label = "shallow\nsummer trough",
           size = 5.2, colour = LS_COL$graymid, fontface = "italic", lineheight = 0.9) +
  scale_fill_manual(values = c(`FALSE` = LS_COL$graymid, `TRUE` = LS_COL$red)) +
  scale_y_continuous(expand = expansion(c(0, 0.12))) +
  labs(title = "Live shopping has a <span style='color:#CD0000;'>holiday-quarter</span> rhythm",
       subtitle = "Average search-interest index by calendar month across the window (dashed line = window average of 100).",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Avg. index") +
  theme_ls() + theme(panel.grid.major.x = element_blank())
save_fig(p8, "fig_seasonality.png", h = 120)

# ── 9. Lead-lag: selling leads shopping ─────────────────────────────────────
ll <- readr::read_csv(file.path(data_dir, "leadlag.csv"), show_col_types = FALSE)
p9 <- ggplot(ll, aes(lag_months, corr, fill = corr > 0)) +
  geom_col(width = 0.7) +
  geom_vline(xintercept = 0, colour = LS_COL$ink, linewidth = 0.4) +
  annotate("text", x = -4.2, y = max(ll$corr) * 1.04, label = "selling leads shopping",
           size = 6, colour = LS_COL$red, fontface = "bold") +
  annotate("text", x = 4.2, y = max(ll$corr) * 1.04, label = "shopping leads selling",
           size = 6, colour = LS_COL$graymid) +
  scale_fill_manual(values = c(`TRUE` = LS_COL$red, `FALSE` = LS_COL$graymid)) +
  scale_x_continuous(breaks = -6:6) +
  labs(title = "Sellers move first: <span style='color:#CD0000;'>live-selling</span> search leads live-<b>shopping</b> by about two quarters",
       subtitle = "Correlation between month-over-month change in the two indices at different lags. Peak correlation sits where selling leads.",
       caption = ls_source_caption(WINDOW), x = "Lag (months) - negative = selling leads", y = "Correlation") +
  theme_ls()
save_fig(p9, "fig_leadlag.png", h = 120)

# ── 10. Platform share-of-search over time ──────────────────────────────────
ps <- readr::read_csv(file.path(data_dir, "platform_share.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month))
ps_keep <- c("Whatnot", "TikTok", "QVC/HSN", "eBay", "Facebook", "Instagram", "Amazon")
ps2 <- ps |> filter(platform %in% ps_keep) |>
  mutate(platform = factor(platform, levels = ps_keep)) |>
  group_by(platform) |> arrange(month) |>
  mutate(share_s = zoo::rollmean(share, 3, fill = NA, align = "right")) |> ungroup()
p10 <- ggplot(ps2, aes(month, share_s, fill = platform)) +
  geom_area(position = "fill", colour = "white", linewidth = 0.15) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_fill_manual(values = c(Whatnot = "#E0A800", TikTok = LS_COL$ink, `QVC/HSN` = LS_COL$red,
                               eBay = "#2CA02C", Facebook = "#1F77B4", Instagram = "#9467BD",
                               Amazon = "#FF7F0E")) +
  labs(title = "The rotation, in shares: <span style='color:#E0A800;'>Whatnot</span> and <span style='color:#CD0000;'>QVC/HSN</span> take share as Meta gives it up",
       subtitle = "Share of branded '[platform] live shopping' search by month (3-mo avg). Whatnot rose from ~1% to ~8%.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Share of branded LS search") +
  theme_ls() + theme(legend.position = "right", legend.title = element_blank())
save_fig(p10, "fig_platform_share.png", h = 130)

# ── 11. Commercial value by platform (top-of-page bid) ──────────────────────
cv <- readr::read_csv(file.path(data_dir, "commercial_by_platform.csv"), show_col_types = FALSE) |>
  arrange(median_top_bid) |> mutate(platform = factor(platform, levels = platform))
p11 <- ggplot(cv, aes(median_top_bid, platform)) +
  geom_segment(aes(x = 0, xend = median_top_bid, yend = platform), colour = LS_COL$graymid, linewidth = 0.8) +
  geom_point(size = 4, colour = LS_COL$red) +
  geom_text(aes(label = scales::dollar(median_top_bid)), hjust = -0.4, size = 6, colour = LS_COL$ink) +
  scale_x_continuous(labels = scales::dollar, expand = expansion(c(0, 0.18))) +
  labs(title = "The monetisation gap: <span style='color:#CD0000;'>Whatnot</span> has the audience, not the ad prices",
       subtitle = "Median Google top-of-page bid for that platform's live-shopping keywords. Higher = advertisers pay more to reach that audience.",
       caption = paste0("Source: Google Ads Keyword Planner API (US). Bids converted from micros. ", WINDOW, "."),
       x = "Median top-of-page bid (USD)", y = NULL) +
  theme_ls() + theme(panel.grid.major.y = element_blank())
save_fig(p11, "fig_commercial.png", h = 110)

# ── 12. Device mix by platform ──────────────────────────────────────────────
dv <- readr::read_csv(file.path(data_dir, "device_mix.csv"), show_col_types = FALSE) |>
  tidyr::pivot_longer(c(mobile_pct, desktop_pct, tablet_pct), names_to = "device", values_to = "pct") |>
  mutate(device = recode(device, mobile_pct = "Mobile", desktop_pct = "Desktop", tablet_pct = "Tablet"),
         device = factor(device, levels = c("Tablet", "Desktop", "Mobile")),
         segment = factor(segment, levels = rev(unique(segment))))
p12 <- ggplot(dv, aes(pct, segment, fill = device)) +
  geom_col(width = 0.74) +
  geom_vline(xintercept = 50, linetype = 2, colour = "white", linewidth = 0.4) +
  scale_x_continuous(labels = scales::percent_format(scale = 1), expand = c(0, 0)) +
  scale_fill_manual(values = c(Mobile = LS_COL$red, Desktop = LS_COL$graymid, Tablet = "#D8D8D8")) +
  labs(title = "Live shopping is a <span style='color:#CD0000;'>phone</span> behaviour - even for 40-year-old TV brands",
       subtitle = "Share of search by device. QVC/HSN is the most mobile of all; collectibles platforms skew slightly more desktop.",
       caption = ls_source_caption(WINDOW), x = NULL, y = NULL) +
  theme_ls() + theme(legend.position = "top", legend.title = element_blank())
save_fig(p12, "fig_device.png", h = 130)

# ── 13. Question taxonomy over time ─────────────────────────────────────────
qt <- readr::read_csv(file.path(data_dir, "question_taxonomy.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month)) |> filter(qtype != "why") |>
  group_by(qtype) |> arrange(month) |>
  mutate(s = zoo::rollmean(searches, 3, fill = NA, align = "right")) |> ungroup() |>
  mutate(qtype = recode(qtype, how = "How (participate)", `is/are` = "Is it legit? (trust)", what = "What is it? (awareness)"))
p13 <- ggplot(qt, aes(month, s, colour = qtype)) +
  geom_line(linewidth = 1.3) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_manual(values = c("How (participate)" = LS_COL$red,
                                 "Is it legit? (trust)" = LS_COL$ink,
                                 "What is it? (awareness)" = "#1F77B4")) +
  labs(title = "From \"what is it\" to \"how do I do it\": the questions mature with the market",
       subtitle = "Monthly search volume of question queries about live shopping, by type (3-mo avg).",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Monthly searches") +
  theme_ls() + theme(legend.position = "top", legend.title = element_blank())
save_fig(p13, "fig_questions.png", h = 120)

# ── 14. Concentration: Whatnot share over time ──────────────────────────────
cc <- readr::read_csv(file.path(data_dir, "concentration.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month),
         wn_s = zoo::rollmean(whatnot_share, 3, fill = NA, align = "right"),
         t5_s = zoo::rollmean(top5_share, 3, fill = NA, align = "right"))
p14 <- ggplot(cc, aes(month)) +
  geom_area(aes(y = wn_s), fill = LS_COL$whatnot, alpha = 0.55) +
  geom_line(aes(y = wn_s), colour = "#C9A800", linewidth = 1.5) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(title = "From a rounding error to a real share: <span style='color:#C9A800;'>Whatnot</span>'s slice of branded live-shopping search",
       subtitle = "Whatnot's share of all branded '[platform] live shopping' search, 3-month moving average.",
       caption = ls_source_caption(WINDOW), x = NULL, y = "Share of branded LS search") +
  theme_ls()
save_fig(p14, "fig_concentration.png", h = 115)

# ── 15. Whatnot GMV growth by category (from public reporting) ──────────────
gmv_cat <- tibble::tribble(
  ~category, ~growth,
  "Beauty", 791, "Electronics", 444, "Jewelry", 259, "Women's fashion", 223
) |> arrange(growth) |> mutate(category = factor(category, levels = category))
p15 <- ggplot(gmv_cat, aes(growth, category)) +
  geom_segment(aes(x = 0, xend = growth, yend = category), colour = LS_COL$graymid, linewidth = 0.9) +
  geom_point(size = 5, colour = LS_COL$whatnot) +
  geom_point(size = 5, shape = 21, colour = "#C9A800", fill = NA, stroke = 1) +
  geom_text(aes(label = paste0("+", growth, "%")), hjust = -0.35, size = 6.4, colour = LS_COL$ink) +
  scale_x_continuous(labels = function(x) paste0("+", x, "%"), expand = expansion(c(0, 0.16))) +
  labs(title = "Beyond collectibles: where Whatnot's <span style='background-color:#FFF351;'>&nbsp;dollars&nbsp;</span> are growing fastest",
       subtitle = "Whatnot GMV growth by category, 2025 vs 2024 (company reporting). The mass-retail verticals are scaling hardest.",
       caption = "Source: Whatnot public reporting / trade press, 2025-2026. Search data elsewhere from Google Ads Keyword Planner API.",
       x = "GMV growth, 2025 YoY", y = NULL) +
  theme_ls() + theme(panel.grid.major.y = element_blank())
save_fig(p15, "fig_gmv_categories.png", h = 105)

cat("\nAll figures written to", fig_dir, "\n")
print(list.files(fig_dir))
