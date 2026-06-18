"""Full seed pull via the multi-seed keyword-ideas endpoint.

Reads output-2026/arg_df_gapi.csv (built by 00_prep_seeds.py), expands every
seed batch into keyword ideas, and saves raw + flattened results.

Run with the ads-api venv (long-running):
    cd ../ads-api && uv run python <abs path>/pipeline-2026/01_full_pull.py
"""

import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import ADS_API_DIR, ADS_YAML_PATH, GADS_VERSION, OUTPUT_DIR, FULL_TAG

sys.path.insert(0, ADS_API_DIR)
from kwideas_funcs import R_generate_kw_ideas_multi_tenac
from pyevangelion_powerfuncs_ai import (
    process_row_arg_dicts_simple, get_summary_table, get_final_res_df, save_pickle,
)
from google.ads.googleads.client import GoogleAdsClient


def main() -> None:
    client = GoogleAdsClient.load_from_storage(ADS_YAML_PATH, version=GADS_VERSION)

    arg_path = os.path.join(OUTPUT_DIR, "arg_df_gapi.csv")
    args_df = pd.read_csv(arg_path)
    print(f"Loaded {len(args_df)} API calls from {arg_path}")
    arg_dicts = args_df.to_dict(orient="records")

    results = process_row_arg_dicts_simple(
        arg_dicts, R_generate_kw_ideas_multi_tenac, client=client
    )

    save_pickle(results, os.path.join(OUTPUT_DIR, f"results_{FULL_TAG}.pkl"))
    summary_df = get_summary_table(results)
    final_df = get_final_res_df(results)
    summary_df.to_csv(os.path.join(OUTPUT_DIR, f"summary_{FULL_TAG}.csv"), index=False)
    final_df.to_pickle(os.path.join(OUTPUT_DIR, f"final_df_{FULL_TAG}.pkl"))

    print(f"\nSaved results_{FULL_TAG}.pkl / summary_{FULL_TAG}.csv / final_df_{FULL_TAG}.pkl")
    print(f"Final flattened rows: {len(final_df):,}")
    if "exception" in summary_df.columns:
        rate = (summary_df["exception"] == "success").mean() * 100
        print(f"Success rate: {rate:.0f}%")


if __name__ == "__main__":
    main()
