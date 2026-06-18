"""Test the Google Ads API connection before the full seed pull.

Run with the ads-api venv:
    cd ../ads-api && uv run python <abs path>/pipeline-2026/00b_test_api_pull.py
"""

import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import (
    ADS_API_DIR, ADS_YAML_PATH, GADS_VERSION, OUTPUT_DIR, N_MONTHS,
    TEST_KEYWORDS, TEST_LOCATION_ID, TEST_LANGUAGE_ID, TEST_REFERENCE_VOLUMES,
)

sys.path.insert(0, ADS_API_DIR)
from kwideas_funcs import R_generate_kw_ideas_tenac
from pyevangelion_powerfuncs_ai import (
    process_row_arg_dicts_simple, get_summary_table, get_final_res_df, save_pickle,
)
from google.ads.googleads.client import GoogleAdsClient


def main() -> None:
    client = GoogleAdsClient.load_from_storage(ADS_YAML_PATH, version=GADS_VERSION)

    arg_df = pd.DataFrame([
        {"location_ids": TEST_LOCATION_ID, "language_id": TEST_LANGUAGE_ID,
         "seed_term": kw, "iteration": i}
        for i, kw in enumerate(TEST_KEYWORDS, start=1)
    ])
    arg_dicts = arg_df.to_dict(orient="records")

    results = process_row_arg_dicts_simple(arg_dicts, R_generate_kw_ideas_tenac, client=client)

    save_pickle(results, os.path.join(OUTPUT_DIR, "test_results.pkl"))
    summary_df = get_summary_table(results)
    final_df = get_final_res_df(results)
    summary_df.to_csv(os.path.join(OUTPUT_DIR, "test_summary.csv"), index=False)
    final_df.to_pickle(os.path.join(OUTPUT_DIR, "test_final_df.pkl"))

    print("\n=== summary ===")
    print(summary_df)

    # success rate
    if "exception" in summary_df.columns:
        rate = (summary_df["exception"] == "success").mean() * 100
        print(f"\nSuccess rate: {rate:.0f}%")

    # ballpark check on the seed rows themselves
    cols = {c.lower(): c for c in final_df.columns}
    kw_col = cols.get("keyword", "keyword")
    vol_col = cols.get("avg_monthly_searches", "avg_monthly_searches")
    months_col = "searches_past_months" if "searches_past_months" in final_df.columns else cols.get("searches_past_months")

    ok = True
    for kw, ref in TEST_REFERENCE_VOLUMES.items():
        row = final_df[final_df[kw_col] == kw]
        if row.empty:
            print(f"  ! '{kw}' not found in results")
            ok = False
            continue
        vol = float(row.iloc[0][vol_col])
        within = 0.25 * ref <= vol <= 4 * ref
        print(f"  {kw}: {vol:,.0f} (ref ~{ref:,}) -> {'OK' if within else 'OUT OF RANGE'}")
        ok = ok and within
        # month count
        m = row.iloc[0][months_col]
        if hasattr(m, "__len__") and len(m) != N_MONTHS:
            print(f"    ! '{kw}' has {len(m)} months, expected {N_MONTHS}")
            ok = False

    print("\nTest pull successful — safe to run full seed pull." if ok
          else "\nTest pull FAILED — inspect output before full pull.")


if __name__ == "__main__":
    main()
