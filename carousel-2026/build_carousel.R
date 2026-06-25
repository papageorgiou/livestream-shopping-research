# Build a 9-slide LinkedIn carousel (PDF) on US live-shopping search interest.
# Each slide: 1080 x 1350 px (4:5 portrait) -> combined into one PDF.
# Run: Rscript carousel-2026/build_carousel.R

suppressMessages({
  library(ggplot2); library(dplyr); library(readr); library(stringr)
  library(showtext); library(sysfonts); library(patchwork); library(scales)
  library(zoo); library(magick)
})

# ---- paths ----
ROOT <- "/Users/alexp/gd_alpapag/apclients/livestream-shopping-research"
DATA <- file.path(ROOT, "report-2026", "data")
OUT  <- file.path(ROOT, "carousel-2026")
SLD  <- file.path(OUT, "slides")
dir.create(SLD, showWarnings = FALSE, recursive = TRUE)

# ---- fonts ----
HEAD <- "head"; BODY <- "body"; NUM <- "num"
ok <- TRUE
tryCatch({
  font_add_google("Oswald", HEAD)
  font_add_google("Barlow", BODY)
  font_add_google("Archivo Black", NUM)
}, error = function(e) { ok <<- FALSE })
if (!ok) { HEAD <- "sans"; BODY <- "sans"; NUM <- "sans" }
showtext_auto(); showtext_opts(dpi = 150)

# ---- palette (charcoal + coral on white) ----
INK   <- "#161618"   # near-black headline
GRAY  <- "#6C757D"   # muted body
RED   <- "#E63946"   # coral accent
REDD  <- "#B5202C"   # deep red
LINEG <- "#E3E3E6"   # gridlines
SOFT  <- "#FCE8EA"   # pale red fill
BG    <- "#FFFFFF"
SRC   <- "Source: Google Ads Keyword Planner, US, Jun 2022–May 2026  ·  ~79k keywords"

# ---- canvas helpers (coordinate system 0..100) ----
W <- 1080; H <- 1350
canvas <- function() {
  ggplot() +
    coord_cartesian(xlim = c(0, 100), ylim = c(0, 100), expand = FALSE, clip = "off") +
    scale_x_continuous(breaks = NULL) + scale_y_continuous(breaks = NULL) +
    theme_void() +
    theme(plot.background = element_rect(fill = BG, color = NA),
          plot.margin = margin(0, 0, 0, 0))
}
# accent bars + kicker + footer common to every slide
chrome <- function(p, kicker) {
  p +
    annotate("rect", xmin = 0, xmax = 100, ymin = 98.6, ymax = 100, fill = RED) +
    annotate("rect", xmin = 0, xmax = 100, ymin = 0, ymax = 0.9, fill = RED) +
    annotate("text", x = 6, y = 95.2, label = toupper(kicker), hjust = 0, vjust = 1,
             family = HEAD, fontface = "bold", size = 5.4, color = RED) +
    annotate("text", x = 6, y = 3.1, label = SRC, hjust = 0, vjust = 0,
             family = BODY, size = 3.5, color = GRAY) +
    annotate("text", x = 94, y = 3.1, label = "LIVE SHOPPING INDEX", hjust = 1, vjust = 0,
             family = HEAD, fontface = "bold", size = 3.6, color = INK)
}
txt <- function(p, x, y, label, size, color = INK, family = BODY, face = "plain",
                hjust = 0, vjust = 1, lh = 1) {
  p + annotate("text", x = x, y = y, label = label, hjust = hjust, vjust = vjust,
               family = family, fontface = face, size = size, color = color, lineheight = lh)
}
save_slide <- function(p, n) {
  f <- file.path(SLD, sprintf("slide_%02d.png", n))
  ggsave(f, p, width = W/150, height = H/150, dpi = 150, bg = BG)
  f
}

# chart theme for inset plots
theme_chart <- function(base = 15) {
  theme_minimal(base_family = BODY, base_size = base) +
    theme(
      plot.background  = element_rect(fill = NA, color = NA),
      panel.background = element_rect(fill = NA, color = NA),
      panel.grid.major.y = element_line(color = LINEG, linewidth = 0.5),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.title = element_blank(),
      axis.text  = element_text(color = GRAY, size = base),
      axis.ticks = element_blank(),
      legend.position = "none",
      plot.margin = margin(2, 6, 2, 2)
    )
}
ins <- function(p, l, b, r, t) inset_element(p, left = l, bottom = b, right = r, top = t,
                                             align_to = "full", on_top = TRUE)

# =====================================================================
# DATA
# =====================================================================
ls   <- read_csv(file.path(DATA, "ls_index.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month), roll = rollmean(index_value, 3, fill = NA, align = "right"))
sell <- read_csv(file.path(DATA, "live_sell_index.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month), roll = rollmean(index_value, 3, fill = NA, align = "right"))
ll   <- read_csv(file.path(DATA, "leadlag.csv"), show_col_types = FALSE)
hm   <- read_csv(file.path(DATA, "headline_metrics.csv"), show_col_types = FALSE)
yoy_25 <- round(hm$yoy_pct[hm$year == 2025])   # 2025 vs 2024 growth, %
wn   <- read_csv(file.path(DATA, "whatnot_terms.csv"), show_col_types = FALSE) |>
  filter(keyword == "whatnot") |> mutate(month = as.Date(month))
emer <- read_csv(file.path(DATA, "emergence.csv"), show_col_types = FALSE)
tg   <- read_csv(file.path(DATA, "top_growers.csv"), show_col_types = FALSE) |>
  filter(keyword != "whatnot") |> arrange(desc(slope)) |> head(8)
tt   <- read_csv(file.path(DATA, "trust_terms.csv"), show_col_types = FALSE) |>
  mutate(month = as.Date(month)) |> group_by(month) |>
  summarise(s = sum(roll_avg, na.rm = TRUE), .groups = "drop")

# =====================================================================
# SLIDE 1 — HOOK
# =====================================================================
s1 <- canvas() |> chrome("2026 Search-Interest Report") |>
  txt(6, 90, "US Live Shopping\nJust Broke Out", 14, INK, HEAD, "bold", lh = 0.95) |>
  txt(6, 64, "After two years of decline, search interest\nfor live shopping surged in 2025.", 6.4, GRAY, BODY, lh = 1.05)
s1 <- s1 +
  annotate("text", x = 6, y = 47, label = paste0("+", yoy_25, "%"), hjust = 0, vjust = 1, family = NUM, size = 41, color = RED) +
  annotate("text", x = 7, y = 20.5, label = "growth in average monthly searches, 2025 vs 2024", hjust = 0, vjust = 1, family = BODY, size = 6, color = INK)
s1 <- s1 + annotate("text", x = 94, y = 90, label = "swipe >", hjust = 1, vjust = 1, family = HEAD, fontface = "bold", size = 5.5, color = GRAY)
save_slide(s1, 1)

# =====================================================================
# SLIDE 2 — THE TREND (annotated line)
# =====================================================================
p2 <- ggplot(ls, aes(month, index_value)) +
  annotate("rect", xmin = as.Date("2024-04-01"), xmax = as.Date("2024-09-01"),
           ymin = -Inf, ymax = Inf, fill = SOFT, alpha = 0.6) +
  geom_hline(yintercept = 100, color = GRAY, linewidth = 0.4, linetype = "22") +
  geom_line(color = LINEG, linewidth = 0.6) +
  geom_line(aes(y = roll), color = RED, linewidth = 1.5) +
  annotate("text", x = as.Date("2024-05-15"), y = 60, label = "Bottoms out\nmid-2024",
           family = BODY, color = GRAY, size = 5, lineheight = 0.95) +
  annotate("point", x = as.Date("2025-05-01"), y = max(ls$roll, na.rm = TRUE), color = REDD, size = 3) +
  annotate("text", x = as.Date("2025-05-01"), y = max(ls$roll, na.rm = TRUE) + 18, label = "Breakout\nthrough 2025",
           family = BODY, fontface = "bold", color = REDD, size = 5, hjust = 0.5, lineheight = 0.95) +
  scale_y_continuous(labels = function(x) x, limits = c(0, 200)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_chart(15)
s2 <- canvas() |> chrome("The Trend") |>
  txt(6, 89, "Two Years Down, Then a Surge", 11.2, INK, HEAD, "bold") |>
  txt(6, 79, "Search-interest index, 100 = June 2022. 3-month average.", 5.6, GRAY)
s2 <- s2 + ins(p2, 0.04, 0.08, 0.99, 0.74)
save_slide(s2, 2)

# =====================================================================
# SLIDE 3 — THE REVERSAL (yearly yoy bars)
# =====================================================================
yb <- hm |> filter(!is.na(yoy_pct)) |>
  mutate(year = factor(year), pos = yoy_pct >= 0,
         lab = paste0(ifelse(pos, "+", ""), round(yoy_pct), "%"))
p3 <- ggplot(yb, aes(year, yoy_pct, fill = pos)) +
  geom_col(width = 0.68) +
  geom_hline(yintercept = 0, color = INK, linewidth = 0.5) +
  geom_text(aes(label = lab, vjust = ifelse(pos, -0.4, 1.3)),
            family = HEAD, fontface = "bold", size = 7,
            color = ifelse(yb$pos, REDD, GRAY)) +
  scale_fill_manual(values = c(`TRUE` = RED, `FALSE` = "#C9CCD1")) +
  scale_y_continuous(limits = c(-30, 62)) +
  theme_chart(16) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_blank())
s3 <- canvas() |> chrome("The Reversal") |>
  txt(6, 89, "The Decline Snapped in 2025", 11.2, INK, HEAD, "bold") |>
  txt(6, 79, "Year-over-year change in average monthly search interest.", 5.6, GRAY)
s3 <- s3 + ins(p3, 0.04, 0.10, 0.99, 0.74)
save_slide(s3, 3)

# =====================================================================
# SLIDE 4 — SELLERS MOVE FIRST (the leading indicator)
# =====================================================================
# live-selling (supply-side) index has more than doubled and leads consumer
# interest: month-over-month change in selling search leads shopping by ~2 quarters.
sell_growth <- round(tail(sell$roll[!is.na(sell$roll)], 1)) - 100   # % above June-2022 base
lead_mo <- abs(ll$lag_months[which.max(ll$corr)])                   # best-correlation lead, months
p4 <- ggplot(sell, aes(month, index_value)) +
  geom_hline(yintercept = 100, color = GRAY, linewidth = 0.4, linetype = "22") +
  geom_line(color = LINEG, linewidth = 0.6) +
  geom_area(aes(y = roll), fill = SOFT, color = NA) +
  geom_line(aes(y = roll), color = RED, linewidth = 1.5) +
  annotate("point", x = max(sell$month), y = tail(sell$roll, 1), color = REDD, size = 3) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) x) +
  theme_chart(14)
s4 <- canvas() |> chrome("The Tell") |>
  txt(6, 89, "Sellers Move First", 13, INK, HEAD, "bold") |>
  txt(6, 80, "Seller-side search (“how to sell on whatnot,” “tiktok shop\nseller center”) leads consumer interest — an early warning.", 5.6, GRAY, lh = 1.05)
s4 <- s4 +
  annotate("text", x = 6, y = 70, label = paste0("~", lead_mo, " mo"), hjust = 0, vjust = 1, family = NUM, size = 21, color = RED) +
  annotate("text", x = 49, y = 67, label = "the live-selling index\nleads live shopping —\nabout two quarters early", hjust = 0, vjust = 1, family = BODY, size = 5.2, color = INK, lineheight = 1) +
  annotate("text", x = 6, y = 50.5, label = paste0("Supply-side search is up +", sell_growth, "% since 2022 — it runs hotter than demand."),
           hjust = 0, vjust = 1, family = BODY, fontface = "bold", size = 5, color = REDD)
s4 <- s4 + ins(p4, 0.04, 0.10, 0.99, 0.44)
save_slide(s4, 4)

# =====================================================================
# SLIDE 5 — WHATNOT KEEPS GROWING
# =====================================================================
p5 <- ggplot(wn, aes(month, roll_avg)) +
  geom_area(fill = SOFT, color = NA) +
  geom_line(color = RED, linewidth = 1.6) +
  annotate("point", x = max(wn$month), y = tail(wn$roll_avg,1), color = REDD, size = 3) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = label_number(scale = 1e-3, suffix = "k")) +
  theme_chart(15)
s5 <- canvas() |> chrome("The Breakout Brand") |>
  txt(6, 89, "Whatnot Keeps Climbing", 11.2, INK, HEAD, "bold") |>
  txt(6, 79, "Monthly US searches for “whatnot,” 3-month average.", 5.6, GRAY)
s5 <- s5 +
  annotate("text", x = 6, y = 75, label = "6.6×", hjust = 0, vjust = 1, family = NUM, size = 17, color = RED) +
  annotate("text", x = 32, y = 72.5, label = "growth in 3 years — now at\nits highest level on record", hjust = 0, vjust = 1, family = BODY, size = 5, color = INK, lineheight = 1)
s5 <- s5 + ins(p5, 0.04, 0.08, 0.99, 0.62)
save_slide(s5, 5)

# =====================================================================
# SLIDE 6 — NEW ENTRANTS (lollipop by peak, labeled with debut)
# =====================================================================
ne <- emer |> filter(keyword %in% c("fanatics live","ebay live","palmstreet","talkshoplive")) |>
  mutate(name = recode(keyword, "fanatics live"="Fanatics Live", "ebay live"="eBay Live",
                       "palmstreet"="Palmstreet", "talkshoplive"="TalkShopLive"),
         name = factor(name, levels = name[order(peak)]))
p6 <- ggplot(ne, aes(peak, name)) +
  geom_segment(aes(x = 0, xend = peak, y = name, yend = name), color = LINEG, linewidth = 1.4) +
  geom_point(color = RED, size = 6.5) +
  geom_text(aes(label = label_number(scale = 1e-3, suffix = "k", accuracy = 0.1)(peak)),
            hjust = -0.35, family = HEAD, fontface = "bold", size = 6, color = INK) +
  geom_text(aes(x = 0, label = paste0("  debut ", first_meaningful_month)),
            hjust = 0, vjust = 2.3, family = BODY, size = 4.6, color = GRAY) +
  scale_x_continuous(limits = c(0, max(ne$peak) * 1.25)) +
  theme_chart(17) +
  theme(panel.grid.major.y = element_blank(), axis.text.x = element_blank())
s6 <- canvas() |> chrome("New Entrants") |>
  txt(6, 89, "A Wave of New Live-Selling Apps", 10.6, INK, HEAD, "bold") |>
  txt(6, 79, "Challenger platforms, peak monthly US search interest.", 5.6, GRAY)
s6 <- s6 + ins(p6, 0.05, 0.10, 0.97, 0.74)
save_slide(s6, 6)

# =====================================================================
# SLIDE 7 — FASTEST-GROWING QUERIES (horizontal bars)
# =====================================================================
tgp <- tg |> mutate(name = factor(str_to_title(keyword), levels = rev(str_to_title(keyword))))
p7 <- ggplot(tgp, aes(slope, name)) +
  geom_col(fill = RED, width = 0.66) +
  geom_text(aes(label = paste0("+", comma(round(slope)), "/mo")),
            hjust = -0.12, family = HEAD, fontface = "bold", size = 5.3, color = INK) +
  scale_x_continuous(limits = c(0, max(tgp$slope) * 1.45)) +
  theme_chart(15) +
  theme(panel.grid.major.x = element_blank(), axis.text.x = element_blank())
s7 <- canvas() |> chrome("Momentum") |>
  txt(6, 89, "The Fastest-Growing Queries", 11.2, INK, HEAD, "bold") |>
  txt(6, 79, "Monthly searches added per month (trend slope).", 5.6, GRAY)
s7 <- s7 + ins(p7, 0.03, 0.08, 0.99, 0.75)
save_slide(s7, 7)

# =====================================================================
# SLIDE 8 — "IS IT LEGIT?" (trust line)
# =====================================================================
p9 <- ggplot(tt, aes(month, s)) +
  geom_area(fill = SOFT, color = NA) +
  geom_line(color = RED, linewidth = 1.6) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = label_number(scale = 1e-3, suffix = "k")) +
  theme_chart(15)
s9 <- canvas() |> chrome("Going Mainstream") |>
  txt(6, 89, "Now Everyone Asks: Is It Legit?", 10.6, INK, HEAD, "bold") |>
  txt(6, 79, "Monthly searches for “is whatnot legit,” “is tiktok shop legit.”", 5.6, GRAY)
s9 <- s9 +
  annotate("text", x = 6, y = 75, label = "~30×", hjust = 0, vjust = 1, family = NUM, size = 17, color = RED) +
  annotate("text", x = 35, y = 72.5, label = "more trust-checking searches —\na sign the category has gone\nmainstream", hjust = 0, vjust = 1, family = BODY, size = 5, color = INK, lineheight = 1)
s9 <- s9 + ins(p9, 0.04, 0.08, 0.99, 0.58)
save_slide(s9, 8)

# =====================================================================
# SLIDE 9 — TAKEAWAY
# =====================================================================
s10 <- canvas() |> chrome("The Takeaway") |>
  txt(6, 87, "What This Means", 13, INK, HEAD, "bold") |>
  txt(6, 72, "US live shopping has moved from a post-\npandemic slump to a genuine breakout.", 6.4, INK, BODY, lh = 1.05)
bullets <- c(
  paste0("Category search interest rose ~", yoy_25, "% in 2025."),
  "Sellers move first — supply-side search leads by ~2 quarters.",
  "Whatnot keeps growing — up 6.6× in three years.",
  "Trust-checking searches are going mainstream."
)
yb0 <- 62
for (i in seq_along(bullets)) {
  yy <- yb0 - (i - 1) * 9
  s10 <- s10 + annotate("rect", xmin = 6, xmax = 8, ymin = yy - 3.4, ymax = yy - 0.4, fill = RED)
  s10 <- txt(s10, 11, yy, bullets[i], 5.8, INK, BODY)
}
s10 <- s10 +
  annotate("text", x = 6, y = 17, label = "Alex Papageorgiou", hjust = 0, vjust = 0, family = HEAD, fontface = "bold", size = 6, color = INK) +
  annotate("text", x = 6, y = 12.5, label = "Follow for more search-trend breakdowns  >", hjust = 0, vjust = 0, family = BODY, size = 4.8, color = RED)
save_slide(s10, 9)

# =====================================================================
# COMBINE -> PDF
# =====================================================================
files <- file.path(SLD, sprintf("slide_%02d.png", 1:9))
imgs  <- image_read(files)
pdf_path <- file.path(OUT, "live-shopping-carousel.pdf")
image_write(image_join(imgs), pdf_path, format = "pdf")
cat("WROTE", pdf_path, "\n")
cat("Fonts ok:", ok, "\n")
