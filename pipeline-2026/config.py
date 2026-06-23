"""Shared constants for the 2026 live-shopping keyword pipeline.

Two execution environments are used:
  * API pull scripts (00_prep, 00b_test, full pull) need `google-ads` + the
    ads-api helper package, which only work in the ads-api venv (Python 3.12).
    Run them with:  cd ../ads-api && uv run python <abs path to script>
  * Clean / stats scripts (01, 02) need pandas/scipy/matplotlib/pyarrow and run
    in this project's venv:  uv run python pipeline-2026/01_clean.py
"""

import os

import numpy as np

# ── geo / language ──────────────────────────────────────────────────────────
LOCATION_IDS = ["2840"]      # US
LANGUAGE_ID = "1000"          # English
N_MONTHS = 48

# ── seeds ─────────────────────────────────────────────────────────────────────
# Folder of CSVs, each with a `keyword` column. Stacked + deduped by 00_prep.
PROJECT_DIR = "/Users/alexp/gd_alpapag/apclients/livestream-shopping-research"
SEED_SOURCE = os.path.join(PROJECT_DIR, "data/seeds_2026")
SEEDS_PER_CALL = 20           # multi_tenac batches up to 20 seeds per API call

# ── ads-api helpers / credentials ──────────────────────────────────────────────
ADS_API_DIR = "/Users/alexp/gd_alpapag/apclients/ads-api/"
ADS_YAML_PATH = "/Users/alexp/gd_alpapag/apclients/ads-api/ads.yaml"
GADS_VERSION = "v24"

# ── output ─────────────────────────────────────────────────────────────────────
OUTPUT_DIR = os.path.join(PROJECT_DIR, "output-2026")
FULL_TAG = "liveshop2026"     # tag for full-pull output files

# ── test pull sanity references ─────────────────────────────────────────────────
TEST_KEYWORDS = ["news", "pizza", "weather"]
TEST_LOCATION_ID = "2840"
TEST_LANGUAGE_ID = "1000"
TEST_REFERENCE_VOLUMES = {"news": 24_900_000, "pizza": 9_140_000, "weather": 24_000_000}

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── data-quality: spike rationalization & global exclusions ─────────────────────
# Keyword Planner reports monthly volumes in coarse buckets, so a single month can
# jump several buckets (e.g. 390 -> 6,600 -> 260) for one keyword and then fully
# revert. Those isolated one-month spikes are artefacts, not demand, and they badly
# distort summed indices and per-vertical totals (they were inflating the trading-
# card vertical and manufacturing a one-keyword "Jan-2025 spike"). We cap any month
# that is BOTH a sharp local outlier (>= SPIKE_NEIGHBOR_MULT x its larger neighbour)
# AND large relative to the keyword's own typical level (>= SPIKE_MEDIAN_MULT x its
# non-zero median). Capping is to SPIKE_CAP_MULT x the neighbour (floored at the
# keyword's median) so a real, *sustained* rise or a recurring seasonal peak — whose
# neighbours are also elevated — is left untouched, and broad market-wide events that
# move many keywords by ~2x survive. Only egregious isolated artefacts are tamed.
SPIKE_NEIGHBOR_MULT = 4.0   # month must exceed this x its larger immediate neighbour
SPIKE_MEDIAN_MULT = 5.0     # ...and this x the keyword's own non-zero median
SPIKE_CAP_MULT = 2.0        # capped value = this x the larger neighbour (min: median)
SPIKE_FLOOR = 50            # ignore tiny series (max bucket <= this) — nothing to distort

# Keywords removed from every index, vertical, trend and theme table because they are
# ambiguous and not live-shopping intent. "what is a whatnot" is dominated by the
# furniture meaning (a whatnot is a tiered display stand) rather than the marketplace.
GLOBAL_EXCLUDE = {"what is a whatnot"}


def despike_series(series,
                   nbr_mult=SPIKE_NEIGHBOR_MULT,
                   med_mult=SPIKE_MEDIAN_MULT,
                   cap_mult=SPIKE_CAP_MULT,
                   floor=SPIKE_FLOOR):
    """Return a copy of a monthly volume list with isolated one-month spikes capped.

    A month is capped only when it is simultaneously (a) above ``floor``, (b) at
    least ``nbr_mult`` x its larger immediate neighbour, and (c) at least
    ``med_mult`` x the keyword's own non-zero median. The cap is
    ``max(cap_mult x larger_neighbour, median)``. Sustained rises and recurring
    seasonal peaks are preserved because their neighbours are also elevated.
    """
    x = np.asarray(series, dtype=float).copy()
    n = len(x)
    if n < 3:
        return x.tolist()
    nz = x[x > 0]
    med = float(np.median(nz)) if nz.size else 0.0
    for i in range(n):
        lo = x[i - 1] if i > 0 else x[i + 1]
        hi = x[i + 1] if i < n - 1 else x[i - 1]
        nbr = max(lo, hi)
        if (x[i] > floor and x[i] >= nbr_mult * max(nbr, 1.0)
                and x[i] >= med_mult * max(med, 1.0)):
            cap = max(cap_mult * nbr, med)
            if cap < x[i]:
                x[i] = round(cap)
    return x.tolist()
