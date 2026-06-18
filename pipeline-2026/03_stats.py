"""Rolling average + per-keyword linear trend model.

Runs in this project's venv:
    uv run python pipeline-2026/03_stats.py
"""

import json
import os
import sys

import numpy as np
import pandas as pd
from scipy import stats

sys.path.insert(0, os.path.dirname(__file__))
from config import OUTPUT_DIR, N_MONTHS


def main() -> None:
    df = pd.read_parquet(os.path.join(OUTPUT_DIR, "df_clean.parquet"))
    print(f"Loaded {len(df):,} clean keywords")

    # month date axis from saved labels (e.g. 'Jan 2022') -> first of month
    labels_path = os.path.join(OUTPUT_DIR, "month_labels.json")
    if os.path.exists(labels_path):
        labels = json.load(open(labels_path))
        months = pd.to_datetime(pd.Series(labels), format="%m-%Y", errors="coerce")
        if months.isna().any():
            months = pd.date_range("2022-01-01", periods=N_MONTHS, freq="MS").to_series().reset_index(drop=True)
    else:
        months = pd.date_range("2022-01-01", periods=N_MONTHS, freq="MS").to_series().reset_index(drop=True)
    months = list(months)

    # explode to long
    long = df.explode("searches_past_months").reset_index(drop=True)
    long["month_counter"] = long.groupby("keyword").cumcount() + 1
    long["month"] = long.groupby("keyword").cumcount().map(lambda i: months[i])
    long = long.rename(columns={"searches_past_months": "n"})
    long["n"] = pd.to_numeric(long["n"], errors="coerce").fillna(0)

    # per-keyword filters
    def keep_keyword(grp):
        if grp["keyword"].iloc[0] in (None, "", "nan"):
            return False
        if grp["n"].max() <= 20:
            return False
        if (grp["n"] == 0).sum() >= 47:
            return False
        return True

    # drop leading zero months per keyword
    long = long.sort_values(["keyword", "month_counter"])
    long["_started"] = long.groupby("keyword")["n"].transform(lambda s: (s > 0).cummax())
    long = long[long["_started"]].drop(columns="_started")

    keep = long.groupby("keyword").filter(keep_keyword)
    print(f"Keywords after modeling filters: {keep['keyword'].nunique():,}")

    # 3-month rolling average
    keep = keep.sort_values(["keyword", "month_counter"])
    keep["roll_avg"] = (
        keep.groupby("keyword")["n"]
        .transform(lambda s: s.rolling(3, min_periods=1).mean())
        .round()
        .astype(int)
    )
    keep.to_parquet(os.path.join(OUTPUT_DIR, "rolling.parquet"))
    print(f"Wrote rolling.parquet ({len(keep):,} rows)")

    # linear trend model per keyword
    results = []
    for kw, grp in keep.groupby("keyword"):
        grp = grp.sort_values("month_counter")
        if len(grp) < 2:
            continue
        res = stats.linregress(grp["month_counter"], grp["roll_avg"])
        results.append({
            "keyword": kw,
            "avg_monthly_searches": grp["n"].mean(),
            "slope": res.slope,
            "r_squared": res.rvalue ** 2,
        })
    sdf = pd.DataFrame(results)
    sdf = sdf.replace([np.inf, -np.inf], np.nan).dropna(subset=["slope", "r_squared"])
    sdf["slope"] = sdf["slope"].round().astype(int)
    sdf["r_squared"] = sdf["r_squared"].round(1)
    sdf["avg_monthly_searches"] = sdf["avg_monthly_searches"].round().astype(int)
    sdf.to_parquet(os.path.join(OUTPUT_DIR, "kw_trend_stats.parquet"))
    print(f"Wrote kw_trend_stats.parquet ({len(sdf):,} keywords)")
    print("\nTop 20 by slope (fastest-growing):")
    print(sdf.sort_values("slope", ascending=False).head(20).to_string(index=False))


if __name__ == "__main__":
    main()
