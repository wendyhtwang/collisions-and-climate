"""
Validates the monthly precipitation total added to 06's derived-variables
output against the independently-computed total in 05's monthly aggregate.

Both files sum the SAME daily precipitation column over the SAME county-year-
month grouping -- 05 via `sum_vars`, 06 via its `agg_kwargs` -- so they must
agree exactly. Any disagreement means one of the two pipelines is reading a
different set of daily files, grouping differently, or handling missing days
differently, and that is worth knowing regardless of precipitation.

Exits non-zero on any mismatch so it can be wired into a run without being
read by a human every time.

Usage:
    python 06b_validate_ppt_total.py                  # PRISM
    python 06b_validate_ppt_total.py --dataset ERA5
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]

# 05's output, 06's output, and the precipitation-total column each writes.
DATASETS = {
    "PRISM": {
        "monthly": REPO_ROOT / "dataCSV" / "PRISM" / "prism_county_month.csv",
        "derived": REPO_ROOT / "dataCSV" / "PRISM" / "prism_derived_weather_vars.csv",
        "column": "ppt_total",
    },
    "ERA5": {
        "monthly": REPO_ROOT / "dataCSV" / "ERA5" / "era5_county_month.csv",
        "derived": REPO_ROOT / "dataCSV" / "ERA5" / "era5_derived_weather_vars.csv",
        "column": "precip_mm_total",
    },
}

KEYS = ["geoid", "year", "month"]

# Sums of the same float column in a different order, so exact equality is not
# guaranteed; anything above this is a real difference, not float noise.
TOLERANCE_MM = 1e-6

# 45 years x 3,108 counties x 12 months.
EXPECTED_ROWS = 45 * 3108 * 12


def load(path: Path, column: str, label: str) -> pd.DataFrame:
    if not path.exists():
        sys.exit(f"FAIL: {label} file not found:\n  {path}")
    try:
        df = pd.read_csv(path, usecols=KEYS + [column], dtype={"geoid": str})
    except ValueError:
        sys.exit(
            f"FAIL: '{column}' is not a column in the {label} file:\n  {path}\n"
            "       Has 06 been re-run since the precipitation total was added?"
        )
    return df


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", choices=sorted(DATASETS), default="PRISM")
    args = parser.parse_args()

    spec = DATASETS[args.dataset]
    column = spec["column"]
    print(f"=== {args.dataset}: validating '{column}' ===")

    monthly = load(spec["monthly"], column, "05 monthly-aggregate")
    derived = load(spec["derived"], column, "06 derived-variables")

    merged = monthly.merge(
        derived, on=KEYS, suffixes=("_05", "_06"), how="outer", indicator=True
    )

    failures = []

    # 1. Coverage: every county-month in one file is in the other.
    counts = merged["_merge"].value_counts()
    print("\nRow coverage:")
    print(counts.to_string())
    unmatched = merged[merged["_merge"] != "both"]
    if not unmatched.empty:
        failures.append(f"{len(unmatched):,} county-month row(s) present in only one file")
        print("\nFirst unmatched rows:")
        print(unmatched.head(10).to_string(index=False))

    if len(merged) != EXPECTED_ROWS:
        failures.append(
            f"{len(merged):,} distinct county-months, expected {EXPECTED_ROWS:,} "
            "(45 years x 3,108 counties x 12 months)"
        )

    # 2. Agreement on the shared rows.
    both = merged[merged["_merge"] == "both"].copy()
    both["diff"] = (both[f"{column}_05"] - both[f"{column}_06"]).abs()
    worst = both["diff"].max()
    print(f"\nLargest absolute difference on matched rows: {worst:.3e} mm")

    off = both[both["diff"] > TOLERANCE_MM]
    if not off.empty:
        failures.append(f"{len(off):,} row(s) differ by more than {TOLERANCE_MM} mm")
        print("\nWorst offenders:")
        print(off.nlargest(10, "diff").to_string(index=False))

    # 3. Plausibility, so a column of zeros or metres cannot pass silently.
    values = both[f"{column}_06"]
    print(
        f"\nMonthly totals: min {values.min():.1f}, median {values.median():.1f}, "
        f"max {values.max():.1f} mm; {values.isna().sum():,} missing"
    )
    if (values < 0).any():
        failures.append("negative monthly precipitation totals")
    if values.max() < 1:
        failures.append("no monthly total reaches 1mm -- wrong units or wrong column?")

    if failures:
        print("\nFAILED:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)

    print("\nPASSED: 05 and 06 agree on every county-month.")


if __name__ == "__main__":
    main()
