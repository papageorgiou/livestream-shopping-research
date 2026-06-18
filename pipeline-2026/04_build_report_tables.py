"""Build tidy CSV tables for the Quarto/R report from the cleaned pipeline output.

Replicates the original index methodology on the FRESH pull only (no reuse of old
volumes). Index normalized so the first month of the fresh window = 100.

Outputs into report-2026/data/:
  ls_index.csv, live_sell_index.csv         -- headline indices (month, total, index_value)
  platform_index.csv                         -- per-platform monthly search totals
  vertical_index.csv                         -- per-vertical monthly search totals
  whatnot_terms.csv                          -- rolling series for whatnot-related terms
  top_growers.csv                            -- fastest-growing keywords (slope, r2)
  headline_metrics.csv                       -- yearly avg monthly searches etc.

Runs in this project's venv:
    uv run python pipeline-2026/04_build_report_tables.py
"""

import json
import os
import re
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import OUTPUT_DIR, PROJECT_DIR, N_MONTHS

REPORT_DATA = os.path.join(PROJECT_DIR, "report-2026", "data")
os.makedirs(REPORT_DATA, exist_ok=True)

PATTERN_SHOP = r"live shop|livestream shop|live commerce|live stream shop|livestream commerce|live stream commerce"
PATTERN_SELL = r"live sell"
FILTER_OUT = {
    "eat to live shopping list", "livestream shopping platforms",
    "live shopping platform", "live shopping platforms",
    "livestream shopping platform", "live stream shopping platform",
}

# platform -> regex over keyword text
PLATFORMS = {
    "Whatnot": r"whatnot",
    "TikTok": r"tiktok|tik tok",
    "Amazon": r"amazon",
    "eBay": r"ebay",
    "Fanatics": r"fanatics",
    "YouTube": r"youtube",
    "Instagram": r"instagram|\big\b",
    "Facebook": r"facebook|\bfb\b",
    "QVC/HSN": r"qvc|hsn",
    "StockX": r"stockx|stock x",
    "NTWRK": r"ntwrk",
    "TalkShopLive": r"talkshoplive|talk shop live",
    "Popshop": r"popshop",
    "Shopify": r"shopify",
}

# vertical -> regex
VERTICALS = {
    "Trading cards / TCG": r"trading card|\bcard break|pokemon|tcg|sports card|\bcards\b",
    "Sneakers": r"sneaker|\byeezy|jordan",
    "Vintage / thrift": r"vintage|thrift|reseller|preloved|pre-loved|secondhand|second hand",
    "Jewelry": r"jewel|jewellery|jewelry|gold|diamond|gemstone",
    "Beauty": r"beauty|makeup|cosmetic|skincare",
    "Fashion / apparel": r"fashion|apparel|clothing|streetwear|haul",
    "Collectibles / Funko": r"collectible|funko|comic|coin|figure",
}


def load_months():
    labels = json.load(open(os.path.join(OUTPUT_DIR, "month_labels.json")))
    months = pd.to_datetime(pd.Series(labels), format="%m-%Y", errors="coerce")
    if months.isna().any():
        # fall back: assume window ends at most recent and is N_MONTHS long
        end = pd.Timestamp.today().normalize().replace(day=1) - pd.offsets.MonthBegin(2)
        months = pd.date_range(end=end, periods=N_MONTHS, freq="MS").to_series().reset_index(drop=True)
    return list(pd.to_datetime(months))


def monthly_matrix(df):
    """Stack searches_past_months into a (keyword x month) numpy matrix."""
    mat = np.vstack(df["searches_past_months"].apply(lambda x: np.array(x, dtype=float)).values)
    return mat


def build_index(df, months, pattern, out_name):
    sub = df[df["keyword"].str.contains(pattern, case=False, regex=True)]
    sub = sub[~sub["keyword"].isin(FILTER_OUT)]
    mat = monthly_matrix(sub)
    totals = mat.sum(axis=0)
    idx = pd.DataFrame({
        "month": months,
        "total_searches": totals.round().astype(int),
    })
    base = idx["total_searches"].iloc[0]
    idx["index_value"] = (idx["total_searches"] / base * 100).round(1)
    idx.to_csv(os.path.join(REPORT_DATA, out_name), index=False)
    print(f"{out_name}: {len(sub):,} keywords, base={base:,}, "
          f"last index={idx['index_value'].iloc[-1]}")
    return sub, idx


# live-shopping context tokens used to keep vertical buckets on-topic
LS_CONTEXT = (r"live shop|live sell|live selling|live commerce|livestream|live stream|"
              r"live auction|live bid|\bbreak\b|breaks|whatnot|fanatics|ebay live|"
              r"stockx live|ntwrk|live sale|selling live|sell live")


def grouped_monthly(df, months, groups, out_name, label_col, require_context=False):
    rows = []
    for name, pat in groups.items():
        sub = df[df["keyword"].str.contains(pat, case=False, regex=True)]
        if require_context:
            sub = sub[sub["keyword"].str.contains(LS_CONTEXT, case=False, regex=True)]
        sub = sub[~sub["keyword"].isin(FILTER_OUT)]
        if sub.empty:
            continue
        totals = monthly_matrix(sub).sum(axis=0)
        for m, v in zip(months, totals):
            rows.append({label_col: name, "month": m, "searches": int(round(v)),
                         "n_keywords": len(sub)})
    out = pd.DataFrame(rows)
    out.to_csv(os.path.join(REPORT_DATA, out_name), index=False)
    print(f"{out_name}: {out[label_col].nunique()} {label_col}s")
    return out


def main():
    months = load_months()
    print(f"Window: {months[0]:%b %Y} -> {months[-1]:%b %Y} ({len(months)} months)")

    df = pd.read_parquet(os.path.join(OUTPUT_DIR, "df_clean.parquet"))
    # guard: ensure full series
    df = df[df["searches_past_months"].apply(lambda x: len(x) == len(months))].copy()
    print(f"{len(df):,} keywords with full {len(months)}-month series")

    shop_sub, ls_idx = build_index(df, months, PATTERN_SHOP, "ls_index.csv")
    build_index(df, months, PATTERN_SELL, "live_sell_index.csv")

    # platform & vertical breakdowns (within the shopping universe)
    grouped_monthly(shop_sub, months, PLATFORMS, "platform_index.csv", "platform")
    grouped_monthly(df, months, VERTICALS, "vertical_index.csv", "vertical",
                    require_context=True)

    # headline yearly metrics from the LS index
    ls_idx["year"] = pd.to_datetime(ls_idx["month"]).dt.year
    yearly = ls_idx.groupby("year")["total_searches"].mean().round().astype(int).reset_index()
    yearly.rename(columns={"total_searches": "avg_monthly_searches"}, inplace=True)
    yearly["yoy_pct"] = (yearly["avg_monthly_searches"].pct_change() * 100).round(1)
    yearly.to_csv(os.path.join(REPORT_DATA, "headline_metrics.csv"), index=False)
    print("\nHeadline yearly metrics:\n", yearly.to_string(index=False))

    # rolling series slices for specific keyword sets (R can't read parquet)
    rolling = pd.read_parquet(os.path.join(OUTPUT_DIR, "rolling.parquet"))

    def export_terms(terms, out_name):
        sub = rolling[rolling["keyword"].isin(terms)].copy()
        sub.to_csv(os.path.join(REPORT_DATA, out_name), index=False)
        present = sorted(sub["keyword"].unique())
        print(f"{out_name}: {len(present)}/{len(terms)} terms -> {present}")
        return sub

    # whatnot brand trajectory (bare + key sub-terms)
    export_terms(["whatnot", "whatnot app", "whatnot live", "whatnot shopping",
                  "whatnot selling", "whatnot com"], "whatnot_terms.csv")

    # emerging challenger platforms
    export_terms(["fanatics live", "ebay live", "ebay live auction", "stockx live",
                  "ntwrk", "talkshoplive", "popshop live", "palmstreet",
                  "amazon live", "youtube shopping"], "emerging_terms.csv")

    # trust / legitimacy queries
    export_terms(["is whatnot legit", "is whatnot app legit", "is tiktok shop legit",
                  "is tiktok shop safe", "whatnot scam", "tiktok shop scam",
                  "is whatnot safe"], "trust_terms.csv")

    # top growers -- restricted to live-shopping-relevant keywords (seed expansion
    # pulls in unrelated high-volume noise, so filter to the category vocabulary)
    RELEVANCE = (PATTERN_SHOP + r"|" + PATTERN_SELL +
                 r"|live auction|live bidding|card break|whatnot|fanatics live|"
                 r"ebay live|stockx live|ntwrk|talkshoplive|popshop|palmstreet|"
                 r"tiktok shop|live stream sell|livestream sell")
    stats = pd.read_parquet(os.path.join(OUTPUT_DIR, "kw_trend_stats.parquet"))
    rel = stats[stats["keyword"].str.contains(RELEVANCE, case=False, regex=True)]
    rel = rel[~rel["keyword"].isin(FILTER_OUT)]
    top = (rel[(rel["avg_monthly_searches"] >= 30) & (rel["r_squared"] >= 0.4)]
           .sort_values("slope", ascending=False).head(60))
    top.to_csv(os.path.join(REPORT_DATA, "top_growers.csv"), index=False)
    print(f"top_growers.csv: {len(top)} keywords (of {len(rel):,} relevant)")


if __name__ == "__main__":
    main()
