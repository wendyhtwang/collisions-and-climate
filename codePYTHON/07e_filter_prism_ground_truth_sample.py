"""
Filters the production PRISM county-month panel down to the exact
county-year-month rows selected for the ground-truth station comparison.

- Pulls an explicit list of (geoid, year, month) triples rather than a
  cross-product of separate lists, so different counties can be checked
  against different periods.
- Reports (rather than silently drops) any requested row not found in
  production, distinguishing "GEOID not in production at all" from
  "GEOID exists, just not for that year/month."
- Does no aggregation or Earth Engine calls -- a pure row filter, so it
  can't introduce any of the independent-reimplementation concerns the
  06/06b scripts were built to avoid.
"""

from pathlib import Path

import pandas as pd

from ground_truth_utils import filter_to_target_rows

# ---------------------------------------------------------------------
# Configuration -- edit for the exact county-year-months you're checking
# ---------------------------------------------------------------------

# Exact (geoid, year, month) rows to pull -- NOT a cross product of
# separate GEOID/year/month lists, so different counties can specify
# different months (e.g. because that's whichever period you actually
# pulled station data for via 06d for that particular station).
TARGET_COUNTY_MONTHS = [
    ("18009", 2021, 12),  # Blackford County, IN
    ("47127", 2021, 12),  # Moore County, TN
    ("37041", 2021, 12),  # Chowan County, NC
    ("51159", 2021, 12),  # Richmond County, VA
]

REPO_ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "prism_county_month.csv"
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "prism_ground_truth_sample.csv"

ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    if not PRODUCTION_PATH.exists():
        raise FileNotFoundError(f"Production monthly file not found: {PRODUCTION_PATH}")

    print(f"Reading: {PRODUCTION_PATH}")
    production = pd.read_csv(PRODUCTION_PATH, dtype={c: str for c in ID_COLS})
    production["year"] = production["year"].astype(int)
    production["month"] = production["month"].astype(int)

    requested_geoids = {geoid for geoid, _, _ in TARGET_COUNTY_MONTHS}
    selected = filter_to_target_rows(production, TARGET_COUNTY_MONTHS, ID_COLS)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    selected.to_csv(OUTPUT_PATH, index=False)

    print(
        f"\n{len(selected):,} of {len(TARGET_COUNTY_MONTHS)} requested "
        f"county-year-month row(s) found, across {len(requested_geoids)} GEOID(s).\n"
        f"Saved to: {OUTPUT_PATH}"
    )


if __name__ == "__main__":
    main()
