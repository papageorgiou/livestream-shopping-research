"""Validate, clean, and deduplicate the full-pull results.

Runs in this project's venv (pandas/pyarrow/matplotlib):
    uv run python pipeline-2026/02_clean.py
"""

import json
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import OUTPUT_DIR, FULL_TAG, N_MONTHS, GLOBAL_EXCLUDE, despike_series


def main() -> None:
    final_path = os.path.join(OUTPUT_DIR, f"final_df_{FULL_TAG}.pkl")
    summary_path = os.path.join(OUTPUT_DIR, f"summary_{FULL_TAG}.csv")

    df = pd.read_pickle(final_path)
    summary = pd.read_csv(summary_path)
    print(f"Loaded {len(df):,} flattened rows; {len(summary)} API calls")

    # ── validate ────────────────────────────────────────────────────────────
    if "exception" in summary.columns:
        rate = (summary["exception"] == "success").mean() * 100
        print(f"Success rate: {rate:.1f}%")
        if rate < 95:
            print("WARNING: success rate below 95%")
        bad = summary[(summary["exception"] != "success")]
        if len(bad):
            print(f"  {len(bad)} failed calls")

    # standardize column names
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    # response-length histogram
    if "length_of_results" in summary.columns:
        fig, ax = plt.subplots(figsize=(7, 4))
        summary["length_of_results"].clip(0, 1000).plot.hist(bins=50, ax=ax)
        ax.set_xlim(0, 1000)
        ax.set_xlabel("ideas returned per call")
        fig.tight_layout()
        fig.savefig(os.path.join(OUTPUT_DIR, "response_distribution.png"), dpi=120)
        plt.close(fig)

    # ensure list type for the monthly series
    months_col = "searches_past_months"
    df[months_col] = df[months_col].apply(lambda x: list(x) if hasattr(x, "__len__") and not isinstance(x, str) else x)

    # ── assert N_MONTHS ──────────────────────────────────────────────────────
    lengths = df[months_col].apply(lambda x: len(x) if hasattr(x, "__len__") else 0)
    # keep only rows with a full series (the API returns [] for zero-volume kws)
    full = lengths == N_MONTHS
    n_partial = int((~full & (lengths > 0)).sum())
    n_empty = int((lengths == 0).sum())
    print(f"Rows: full={int(full.sum()):,}  partial={n_partial:,}  empty={n_empty:,}")
    if n_partial:
        print(f"  dropping {n_partial} partial-series rows")
    df = df[full].copy()

    # capture canonical month labels from past_months if present
    if "past_months" in df.columns:
        sample = df["past_months"].iloc[0]
        month_labels = list(sample)
        with open(os.path.join(OUTPUT_DIR, "month_labels.json"), "w") as fh:
            json.dump(month_labels, fh)
        print(f"Month window: {month_labels[0]} -> {month_labels[-1]} ({len(month_labels)} months)")

    # ── remove identical keywords ────────────────────────────────────────────
    key_cols = [c for c in ["avg_monthly_searches", "competition_index",
                            "high_top_bid", "low_top_bid"] if c in df.columns]
    df["_series_key"] = df[months_col].apply(lambda x: tuple(x))
    df["_dup_key"] = list(zip(*([df["_series_key"]] + [df[c] for c in key_cols])))

    df["_klen"] = df["keyword"].str.len()
    df = df.sort_values(["_dup_key", "_klen", "keyword"])
    winners = df.drop_duplicates("_dup_key", keep="first")
    n_dropped = len(df) - len(winners)
    print(f"Identical-keyword groups: dropped {n_dropped:,} non-winners")

    # winner -> equivalents mapping
    mapping = (df.groupby("_dup_key")["keyword"].apply(list).reset_index())
    mapping = mapping.merge(winners[["_dup_key", "keyword"]].rename(columns={"keyword": "winner"}),
                            on="_dup_key", how="left")
    mapping[["winner", "keyword"]].rename(columns={"keyword": "equivalents"}).to_parquet(
        os.path.join(OUTPUT_DIR, "identicals_db.parquet"))

    df = winners

    # ── dedup + filter ─────────────────────────────────────────────────────────
    df = df[df["avg_monthly_searches"] > 0]
    df = df.drop_duplicates("keyword", keep="first")
    df = df[["keyword", "avg_monthly_searches", months_col]].reset_index(drop=True)

    # ── global exclusions ────────────────────────────────────────────────────────
    # Ambiguous, non-live-shopping terms removed from the whole universe (see config).
    n_before = len(df)
    df = df[~df["keyword"].isin(GLOBAL_EXCLUDE)].reset_index(drop=True)
    if len(df) < n_before:
        print(f"Excluded {n_before - len(df)} ambiguous keyword(s): "
              f"{sorted(GLOBAL_EXCLUDE)}")

    # ── spike rationalization ────────────────────────────────────────────────────
    # Cap isolated one-month bucket artefacts. The raw series is preserved as
    # `searches_raw`; `searches_past_months` becomes the despiked series that every
    # downstream stage (stats, indices, verticals, theme tables) consumes.
    raw = df[months_col].tolist()
    df["searches_raw"] = raw
    df[months_col] = [despike_series(s) for s in raw]
    n_changed = sum(1 for r, d in zip(raw, df[months_col]) if list(r) != list(d))
    n_cells = sum(sum(1 for a, b in zip(r, d) if a != b)
                  for r, d in zip(raw, df[months_col]))
    print(f"Spike rationalization: capped {n_cells:,} month-cells across "
          f"{n_changed:,} keywords")

    out = os.path.join(OUTPUT_DIR, "df_clean.parquet")
    df.to_parquet(out)
    print(f"\nWrote {out}: {len(df):,} unique keywords")
    print("\nTop 20 by avg monthly searches:")
    print(df.sort_values("avg_monthly_searches", ascending=False).head(20).to_string(index=False))


if __name__ == "__main__":
    main()
