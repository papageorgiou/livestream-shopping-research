"""Mine the cleaned keyword universe for interesting THEMES and print sample
keyword tables (markdown) for the report - regardless of whether they trend.

Idea (from the prior study's notes): don't underestimate low-volume terms; the
biggest early opportunities hide in the long tail. So for each theme we show a
sample of representative keywords with monthly search volume and 4-year trend.

Run: uv run python pipeline-2026/05_theme_spotlights.py > report-2026/theme_tables.md
"""

import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import OUTPUT_DIR

df = pd.read_parquet(os.path.join(OUTPUT_DIR, "df_clean.parquet"))
stats = pd.read_parquet(os.path.join(OUTPUT_DIR, "kw_trend_stats.parquet"))
slope = dict(zip(stats["keyword"], stats["slope"]))

# only keywords that are plausibly about live shopping / selling / auctions
LS_REL = (r"live shop|live sell|live selling|live commerce|livestream|live stream|"
          r"live auction|live bid|\bbreak\b|breaks|whatnot|fanatics|ebay live|"
          r"stockx live|ntwrk|talkshoplive|popshop|palmstreet|tiktok shop|"
          r"qvc|hsn|live sale|shop live|sell live|bidding")
rel = df[df["keyword"].str.contains(LS_REL, case=False, regex=True)].copy()
rel["slope"] = rel["keyword"].map(slope)


def arrow(s):
    if pd.isna(s):
        return "~"
    if s >= 200:
        return "steep up"
    if s >= 30:
        return "up"
    if s <= -200:
        return "steep down"
    if s <= -30:
        return "down"
    return "flat"


def fmt_vol(v):
    v = int(v)
    if v >= 1000:
        return f"{v:,}"
    return str(v)


def table(name, pattern, source=rel, n=12, exclude=None, min_vol=0, sort="avg",
          sample_tail=False):
    sub = source[source["keyword"].str.contains(pattern, case=False, regex=True)].copy()
    if "slope" not in sub.columns:
        sub["slope"] = sub["keyword"].map(slope)
    if exclude:
        sub = sub[~sub["keyword"].str.contains(exclude, case=False, regex=True)]
    sub = sub[sub["avg_monthly_searches"] >= min_vol]
    sub = sub.drop_duplicates("keyword")
    if sub.empty:
        print(f"\n### {name}\n\n(no matches)\n")
        return
    sub = sub.sort_values("avg_monthly_searches", ascending=False)
    if sample_tail and len(sub) > n:
        head = sub.head(n - 4)
        tail = sub.iloc[n - 4:].sample(min(4, len(sub) - (n - 4)), random_state=1)
        sub = pd.concat([head, tail])
    else:
        sub = sub.head(n)
    print(f"\n### {name}\n")
    print(f"_{len(source[source['keyword'].str.contains(pattern, case=False, regex=True)]):,} "
          f"matching keywords in the universe; sample below._\n")
    print("| Keyword | Avg. monthly searches | 4-yr trend |")
    print("|---|---:|---|")
    for _, r in sub.iterrows():
        print(f"| {r['keyword']} | {fmt_vol(r['avg_monthly_searches'])} | {arrow(r['slope'])} |")


print("# Theme spotlight tables (auto-generated)\n")

table("Home shopping convergence: the QVC / HSN long tail",
      r"qvc|hsn", min_vol=200, n=14, exclude=r"\bx videeo|prime")

table("\"How do I sell?\" - the seller learning curve",
      r"how to (sell|go live|start|do).*(whatnot|tiktok|live|stream)|seller|how to sell", n=14)

table("Questions people ask about live shopping",
      r"^(what|how|why|is|are|does|do|can) ", n=14)

table("Comparisons: shoppers and sellers weighing platforms",
      r" vs | versus |alternative|better than| or ", n=12)

table("Tools, apps & software for going live",
      r"\bapp\b|software|platform|tool|website|\bsite\b", n=14,
      exclude=r"legit|safe|scam")

table("Trading cards & breaks - the collectibles engine",
      source=df, pattern=r"card break|breaks live|live break|pokemon.*live|"
      r"sports card|card.*whatnot|whatnot.*card|live.*cards", n=12)

table("Niche breakouts: plants, thrift & vintage going live",
      source=df, pattern=r"palmstreet|plant.*live|live.*plant|thrift.*live|"
      r"live.*thrift|vintage.*live|live.*vintage|reseller live", n=12)

table("Live auctions: a parallel, bid-based behaviour",
      r"live auction|live bid|bidding|auction app|auction live", n=12)

table("The long tail: low-volume niche terms (early signals)",
      r"live shop|live sell|whatnot|live auction|live commerce", n=12,
      min_vol=10, sort="avg", sample_tail=True)
