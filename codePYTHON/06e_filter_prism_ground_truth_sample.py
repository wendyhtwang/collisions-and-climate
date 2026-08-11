"""
Filter dataCSV/PRISM/prism_county_month.csv down to exact (geoid, year,
month) rows picked for the weather-station ground-truth spot check
(06c's candidate list / the 08.07.26 Fri team meeting plan) -- for
comparing against aggregated NOAA station data (06d's output) and/or
PRISM's single-location Data Explorer values.

Does NO Earth Engine calls, no aggregation -- just a row filter, so this
can't introduce any of the aggregation-logic concerns 06/06b were
built to keep independent of. Every column from the production file
passes through unchanged.

OUTPUT: dataCSV/PRISM/spot_check/prism_ground_truth_sample.csv
"""

from pathlib import Path

import pandas as pd

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
    row_key = list(zip(production["geoid"], production["year"], production["month"]))
    selected = production[[key in set(TARGET_COUNTY_MONTHS) for key in row_key]].copy()

    # Report any requested (geoid, year, month) with no matching row --
    # don't silently produce a sample that's missing one you asked for.
    # Distinguish "GEOID not in production at all" (typo, or not yet
    # extracted there) from "GEOID exists, just not for that year/month".
    found_triples = set(zip(selected["geoid"], selected["year"], selected["month"]))
    geoids_in_production = set(production["geoid"].unique())
    missing = [t for t in TARGET_COUNTY_MONTHS if t not in found_triples]
    if missing:
        for geoid, year, month in missing:
            reason = (
                "GEOID not in production at all"
                if geoid not in geoids_in_production
                else "GEOID exists, but not for this year/month"
            )
            print(f"Warning: no row for {geoid} {year}-{month:02d} -- {reason}.")

    selected = selected.sort_values(ID_COLS + ["year", "month"]).reset_index(drop=True)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    selected.to_csv(OUTPUT_PATH, index=False)

    print(
        f"\n{len(selected):,} of {len(TARGET_COUNTY_MONTHS)} requested "
        f"county-year-month row(s) found, across {len(requested_geoids)} GEOID(s).\n"
        f"Saved to: {OUTPUT_PATH}"
    )


if __name__ == "__main__":
    main()
