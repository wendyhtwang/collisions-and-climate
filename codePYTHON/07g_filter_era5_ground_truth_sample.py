"""
Filters the production ERA5 county-month panel down to the exact
county-year-month rows selected for the ground-truth station comparison --
the ERA5 counterpart to 07e_filter_prism_ground_truth_sample.py.

- Reuses the same three county-year-months already vetted for the PRISM
  ground-truth check, rather than re-running
  07c_find_ground_truth_counties.py: the station-density selection logic
  is dataset-agnostic, and reusing the same sites gives a direct
  PRISM-vs-ERA5-vs-station comparison at identical locations.
- Keeps GROUND_TRUTH_CASES in sync by hand with
  07f_extract_era5_ground_truth_points.py and
  07h_compare_era5_ground_truth.py -- see SCRIPT_OVERVIEW.md.
- Does no aggregation or Earth Engine calls -- a pure row filter, same as
  07e, so it can't introduce any of the independent-reimplementation
  concerns 07f was built to avoid.
- Reports (rather than silently drops) any requested row not found in
  production, distinguishing "GEOID not in production at all" from
  "GEOID exists, just not for that year/month" -- same as 07e.
"""

from pathlib import Path

import pandas as pd

from ground_truth_utils import filter_to_target_rows

# Keep in sync with 07f_extract_era5_ground_truth_points.py and
# 07h_compare_era5_ground_truth.py.
GROUND_TRUTH_CASES = [
    {"geoid": "18009", "county": "Blackford", "state": "IN", "year": 2021, "month": 12},
    {"geoid": "37041", "county": "Chowan", "state": "NC", "year": 2000, "month": 1},
    {"geoid": "47127", "county": "Moore", "state": "TN", "year": 1999, "month": 6},
]

REPO_ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "era5_county_month.csv"
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_ground_truth_sample.csv"

ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]


def main() -> None:
    if not PRODUCTION_PATH.exists():
        raise FileNotFoundError(
            f"Production ERA5 monthly file not found: {PRODUCTION_PATH}\n"
            "This means the full-CONUS ERA5 extraction (04_extract_era5_county.py) and/or "
            "its monthly aggregation (05_aggregate_daily_to_monthly.py) haven't been "
            "run yet, or their output hasn't been synced to this machine."
        )

    print(f"Reading: {PRODUCTION_PATH}")
    production = pd.read_csv(PRODUCTION_PATH, dtype={c: str for c in ID_COLS})
    production["year"] = production["year"].astype(int)
    production["month"] = production["month"].astype(int)

    target_triples = [(c["geoid"], c["year"], c["month"]) for c in GROUND_TRUTH_CASES]
    selected = filter_to_target_rows(production, target_triples, ID_COLS)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    selected.to_csv(OUTPUT_PATH, index=False)

    print(
        f"\n{len(selected):,} of {len(GROUND_TRUTH_CASES)} requested county-year-month "
        f"row(s) found.\nSaved to: {OUTPUT_PATH}"
    )


if __name__ == "__main__":
    main()
