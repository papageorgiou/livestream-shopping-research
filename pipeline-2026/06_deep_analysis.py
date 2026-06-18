"""Deep analyses for the 2026 report. Produces tidy CSVs in report-2026/data/
and prints headline numbers for the prose.

Analyses:
  A. Lead-lag: does live-SELLING search lead live-SHOPPING search?
  B. Share-of-search by platform over time (for a stacked-area chart).
  C. Brand vs generic: is the category becoming brand-led (Whatnot) or concept-led?
  D. Concentration: Whatnot's and the top-5's share of branded live-shopping search.
  E. The TikTok-ban natural experiment: spike magnitude + decay.
  F. Emergence timing: when each challenger first showed meaningful search.
  G. Commercial intent: CPC / top-of-page bids / competition among LS keywords.
  H. Device mix: how mobile-first is live-shopping search, by platform/vertical?
  I. Question taxonomy over time (what / how / is / why).

Run: uv run python pipeline-2026/06_deep_analysis.py
"""

import json
import os
import re
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import OUTPUT_DIR, PROJECT_DIR

DATA = os.path.join(PROJECT_DIR, "report-2026", "data")
os.makedirs(DATA, exist_ok=True)

PATTERN_SHOP = (r"live shop|livestream shop|live commerce|live stream shop|"
                r"livestream commerce|live stream commerce")
FILTER_OUT = {"eat to live shopping list", "livestream shopping platforms",
              "live shopping platform", "live shopping platforms",
              "livestream shopping platform", "live stream shopping platform"}

PLATFORMS = {
    "Whatnot": r"whatnot", "TikTok": r"tiktok|tik tok", "Amazon": r"amazon",
    "eBay": r"ebay", "Fanatics": r"fanatics", "YouTube": r"youtube",
    "Instagram": r"instagram", "Facebook": r"facebook|\bfb\b", "QVC/HSN": r"qvc|hsn",
    "Whatnot ": None,
}
VERTICALS = {
    "Trading cards": r"card break|breaks live|live break|sports card|trading card|pokemon.*live",
    "Sneakers": r"sneaker|yeezy|jordan", "Beauty": r"beauty|makeup|cosmetic|skincare",
    "Fashion": r"fashion|apparel|clothing|streetwear", "Jewelry": r"jewel|watch|diamond",
    "Collectibles": r"collectible|funko|comic|coin",
}

months = pd.to_datetime(pd.Series(json.load(open(os.path.join(OUTPUT_DIR, "month_labels.json")))),
                        format="%m-%Y")
months = list(months)


def load():
    df = pd.read_parquet(os.path.join(OUTPUT_DIR, "df_clean.parquet"))
    df = df[df["searches_past_months"].apply(lambda x: len(x) == len(months))].copy()
    return df


def mat(sub):
    return np.vstack(sub["searches_past_months"].apply(lambda x: np.array(x, float)).values)


def banner(t):
    print("\n" + "=" * 70 + f"\n{t}\n" + "=" * 70)


df = load()
shop = df[df["keyword"].str.contains(PATTERN_SHOP, case=False) & ~df["keyword"].isin(FILTER_OUT)]

# ---- A. LEAD-LAG -------------------------------------------------------------
banner("A. Lead-lag: live selling vs live shopping")
ls = pd.read_csv(os.path.join(DATA, "ls_index.csv"), parse_dates=["month"])["index_value"].values
sell = pd.read_csv(os.path.join(DATA, "live_sell_index.csv"), parse_dates=["month"])["index_value"].values
# work on month-over-month change, smoothed (3mo) to reduce noise
def smooth(x, k=3):
    return pd.Series(x).rolling(k, min_periods=1).mean().values
ls_d = np.diff(smooth(ls)); sell_d = np.diff(smooth(sell))
rows = []
for lag in range(-6, 7):
    if lag < 0:      # selling leads shopping by |lag|
        a, b = sell_d[:lag], ls_d[-lag:]
    elif lag > 0:
        a, b = sell_d[lag:], ls_d[:-lag]
    else:
        a, b = sell_d, ls_d
    n = min(len(a), len(b))
    if n > 6:
        r = np.corrcoef(a[:n], b[:n])[0, 1]
        rows.append({"lag_months": lag, "corr": round(r, 3),
                     "meaning": "selling leads" if lag < 0 else ("shopping leads" if lag > 0 else "same month")})
lead = pd.DataFrame(rows)
lead.to_csv(os.path.join(DATA, "leadlag.csv"), index=False)
best = lead.loc[lead["corr"].idxmax()]
print(lead.to_string(index=False))
print(f"\nBest alignment: lag={int(best.lag_months)} ({best.meaning}), r={best.corr}")

# ---- B & C & D. SHARE OF SEARCH ---------------------------------------------
banner("B/C/D. Share-of-search, brand vs generic, concentration")
plat_rows = []
brand_total = np.zeros(len(months))
for name, pat in {k: v for k, v in PLATFORMS.items() if v}.items():
    sub = shop[shop["keyword"].str.contains(pat, case=False)]
    if sub.empty:
        continue
    series = mat(sub).sum(axis=0)
    brand_total += series
    for m, v in zip(months, series):
        plat_rows.append({"platform": name, "month": m, "searches": v})
plat = pd.DataFrame(plat_rows)
# share within branded platform search
tot_by_month = plat.groupby("month")["searches"].transform("sum")
plat["share"] = (plat["searches"] / tot_by_month * 100).round(2)
plat.to_csv(os.path.join(DATA, "platform_share.csv"), index=False)

# brand (any named platform) vs generic (no platform named)
named = shop["keyword"].str.contains("|".join(v for v in PLATFORMS.values() if v), case=False)
brand_series = mat(shop[named]).sum(axis=0)
generic_series = mat(shop[~named]).sum(axis=0)
bg = pd.DataFrame({"month": months, "branded": brand_series, "generic": generic_series})
bg["branded_share"] = (bg["branded"] / (bg["branded"] + bg["generic"]) * 100).round(1)
bg.to_csv(os.path.join(DATA, "brand_vs_generic.csv"), index=False)
print(f"Branded share of live-shopping search: {bg['branded_share'].iloc[0]}% (start) "
      f"-> {bg['branded_share'].iloc[-1]}% (end)")

# concentration: Whatnot share of branded; top-5 share; HHI
conc_rows = []
for i, m in enumerate(months):
    vals = plat[plat["month"] == m].set_index("platform")["searches"]
    tot = vals.sum()
    shares = (vals / tot)
    wn = shares.get("Whatnot", 0) * 100
    top5 = shares.sort_values(ascending=False).head(5).sum() * 100
    hhi = (shares ** 2).sum() * 10000
    conc_rows.append({"month": m, "whatnot_share": round(wn, 1),
                      "top5_share": round(top5, 1), "hhi": round(hhi)})
conc = pd.DataFrame(conc_rows)
conc.to_csv(os.path.join(DATA, "concentration.csv"), index=False)
print(f"Whatnot share of branded LS search: {conc['whatnot_share'].iloc[0]}% -> {conc['whatnot_share'].iloc[-1]}%")
print(f"HHI: {conc['hhi'].iloc[0]} -> {conc['hhi'].iloc[-1]}")

# ---- E. BAN NATURAL EXPERIMENT ----------------------------------------------
banner("E. The TikTok-ban natural experiment (Jan 2025)")
idx = pd.read_csv(os.path.join(DATA, "ls_index.csv"), parse_dates=["month"])
jan = idx[idx["month"] == "2025-01-01"]["index_value"].iloc[0]
base = idx[(idx["month"] >= "2024-07-01") & (idx["month"] <= "2024-12-01")]["index_value"].mean()
post = idx[(idx["month"] >= "2025-06-01") & (idx["month"] <= "2025-12-01")]["index_value"].mean()
print(f"Jan-2025 index: {jan:.0f}")
print(f"Trailing 6-mo avg (Jul-Dec 2024): {base:.0f}  -> spike = {jan/base:.1f}x")
print(f"Post-spike plateau (Jun-Dec 2025): {post:.0f}  -> retained {(post-base)/(jan-base)*100:.0f}% of the jump")

# ---- F. EMERGENCE TIMING -----------------------------------------------------
banner("F. Emergence timing of challengers")
emer_rows = []
for kw in ["whatnot", "fanatics live", "ebay live", "palmstreet", "stockx live", "ntwrk", "talkshoplive"]:
    row = df[df["keyword"] == kw]
    if row.empty:
        continue
    s = np.array(row["searches_past_months"].iloc[0], float)
    # first month exceeding 10% of the keyword's own peak
    thr = 0.1 * s.max()
    first = next((months[i] for i, v in enumerate(s) if v >= thr and v > 50), None)
    emer_rows.append({"keyword": kw, "first_meaningful_month": first.strftime("%b %Y") if first is not None else "n/a",
                      "peak": int(s.max()), "latest": int(s[-1])})
emer = pd.DataFrame(emer_rows)
emer.to_csv(os.path.join(DATA, "emergence.csv"), index=False)
print(emer.to_string(index=False))

# ---- G. COMMERCIAL INTENT ----------------------------------------------------
banner("G. Commercial intent (CPC / top-of-page bid / competition)")
raw = pd.read_pickle(os.path.join(OUTPUT_DIR, "final_df_liveshop2026.pkl"))
raw = raw.drop_duplicates("keyword")
for c in ["high_top_bid", "low_top_bid", "avg_cpc"]:
    raw[c] = pd.to_numeric(raw[c], errors="coerce") / 1e6   # micros -> dollars
LS_REL = (PATTERN_SHOP + r"|live sell|live auction|whatnot|fanatics live|ebay live|"
          r"tiktok shop|stockx live|palmstreet")
rel = raw[raw["keyword"].str.contains(LS_REL, case=False) & ~raw["keyword"].isin(FILTER_OUT)].copy()
rel = rel[(rel["avg_monthly_searches"] >= 100)]
ci = rel[["keyword", "avg_monthly_searches", "competition_index", "high_top_bid", "avg_cpc"]].copy()
top_cpc = ci.sort_values("high_top_bid", ascending=False).head(20)
top_cpc.to_csv(os.path.join(DATA, "commercial_intent.csv"), index=False)
print("Top live-shopping keywords by top-of-page bid ($):")
print(top_cpc.head(15).to_string(index=False))
print(f"\nMedian top-of-page bid across LS keywords: ${rel['high_top_bid'].median():.2f}")
print(f"Median competition index: {rel['competition_index'].median():.0f}")

# commercial value by platform
plat_cpc = []
for name, pat in {k: v for k, v in PLATFORMS.items() if v}.items():
    s = rel[rel["keyword"].str.contains(pat, case=False)]
    if len(s) >= 5:
        plat_cpc.append({"platform": name, "n": len(s),
                         "median_top_bid": round(s["high_top_bid"].median(), 2),
                         "median_competition": round(s["competition_index"].median())})
pcpc = pd.DataFrame(plat_cpc).sort_values("median_top_bid", ascending=False)
pcpc.to_csv(os.path.join(DATA, "commercial_by_platform.csv"), index=False)
print("\nCommercial value by platform:")
print(pcpc.to_string(index=False))

# ---- H. DEVICE MIX -----------------------------------------------------------
banner("H. Device mix (mobile-first?)")
def parse_device(s):
    out = {}
    if not isinstance(s, str):
        return out
    for dev in ["DESKTOP", "MOBILE", "TABLET"]:
        m = re.search(rf"device: {dev}\s*search_count: (\d+)", s)
        if m:
            out[dev] = int(m.group(1))
    return out
dev_rows = []
relraw = raw[raw["keyword"].str.contains(LS_REL, case=False)].copy()
def bucket_devices(frame, label):
    tot = {"DESKTOP": 0, "MOBILE": 0, "TABLET": 0}
    for s in frame["device_searches_group"]:
        for k, v in parse_device(s).items():
            tot[k] += v
    n = sum(tot.values())
    if n:
        dev_rows.append({"segment": label, "mobile_pct": round(tot["MOBILE"] / n * 100, 1),
                         "desktop_pct": round(tot["DESKTOP"] / n * 100, 1),
                         "tablet_pct": round(tot["TABLET"] / n * 100, 1)})
bucket_devices(relraw, "All live shopping")
for name, pat in {k: v for k, v in PLATFORMS.items() if v}.items():
    bucket_devices(relraw[relraw["keyword"].str.contains(pat, case=False)], name)
dev = pd.DataFrame(dev_rows)
dev.to_csv(os.path.join(DATA, "device_mix.csv"), index=False)
print(dev.to_string(index=False))

# ---- I. QUESTION TAXONOMY OVER TIME -----------------------------------------
banner("I. Question taxonomy over time")
q_pat = {"what": r"^what ", "how": r"^how ", "is/are": r"^(is|are) ", "why": r"^why "}
qrows = []
for label, pat in q_pat.items():
    sub = df[df["keyword"].str.contains(pat, case=False, regex=True) &
             df["keyword"].str.contains(LS_REL, case=False)]
    if sub.empty:
        continue
    series = mat(sub).sum(axis=0)
    for m, v in zip(months, series):
        qrows.append({"qtype": label, "month": m, "searches": int(v), "n": len(sub)})
qdf = pd.DataFrame(qrows)
qdf.to_csv(os.path.join(DATA, "question_taxonomy.csv"), index=False)
print(qdf.groupby("qtype")["searches"].agg(["mean"]).round(0).to_string())

print("\nDONE. CSVs written to report-2026/data/")
