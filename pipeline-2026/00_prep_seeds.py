"""Build the API argument dataframe for the full seed pull.

Stacks all seed CSVs in SEED_SOURCE, normalizes + filters keywords, dedups, then
batches them (SEEDS_PER_CALL per row, comma-separated `seed_terms`) for the
multi-seed keyword-ideas endpoint. Writes output-2026/arg_df_gapi.csv.
"""

import glob
import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import (
    SEED_SOURCE, LOCATION_IDS, LANGUAGE_ID, SEEDS_PER_CALL, OUTPUT_DIR,
)


def load_seeds(source: str) -> pd.Series:
    if os.path.isdir(source):
        frames = []
        for path in sorted(glob.glob(os.path.join(source, "*.csv"))):
            df = pd.read_csv(path)
            if "keyword" in df.columns:
                frames.append(df[["keyword"]])
                print(f"  + {os.path.basename(path)}: {len(df)} rows")
        seeds = pd.concat(frames, ignore_index=True)["keyword"]
    else:
        seeds = pd.read_csv(source)["keyword"]
    return seeds


def main() -> None:
    seeds = load_seeds(SEED_SOURCE).dropna().astype(str)
    print(f"Loaded {len(seeds)} raw seeds")

    # normalize
    seeds = (
        seeds.str.lower()
        .str.strip()
        .str.replace(r"\s+", " ", regex=True)
    )

    # filter: length / word count / latin-only
    char_len = seeds.str.len()
    word_len = seeds.str.split().str.len()
    bad_chars = seeds.str.contains(r"[^a-zA-Z\-' ]", regex=True)
    keep = (char_len <= 80) & (word_len <= 10) & (~bad_chars)
    seeds = seeds[keep]

    # dedup
    seeds = seeds.drop_duplicates().reset_index(drop=True)
    print(f"After clean + dedup: {len(seeds)} unique seeds")

    # batch into groups of SEEDS_PER_CALL
    kw = seeds.tolist()
    batches = [kw[i:i + SEEDS_PER_CALL] for i in range(0, len(kw), SEEDS_PER_CALL)]
    rows = []
    for i, batch in enumerate(batches, start=1):
        rows.append({
            "location_ids": LOCATION_IDS[0],  # helper wraps this single id in a list
            "language_id": LANGUAGE_ID,
            "seed_terms": ",".join(batch),
            "iteration": i,
        })
    arg_df = pd.DataFrame(rows)

    out = os.path.join(OUTPUT_DIR, "arg_df_gapi.csv")
    arg_df.to_csv(out, index=False)
    print(f"\nWrote {out}")
    print(f"  {len(arg_df)} API calls ({len(seeds)} seeds, {SEEDS_PER_CALL}/call)")


if __name__ == "__main__":
    main()
