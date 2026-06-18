"""Shared constants for the 2026 live-shopping keyword pipeline.

Two execution environments are used:
  * API pull scripts (00_prep, 00b_test, full pull) need `google-ads` + the
    ads-api helper package, which only work in the ads-api venv (Python 3.12).
    Run them with:  cd ../ads-api && uv run python <abs path to script>
  * Clean / stats scripts (01, 02) need pandas/scipy/matplotlib/pyarrow and run
    in this project's venv:  uv run python pipeline-2026/01_clean.py
"""

import os

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
