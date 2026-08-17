"""
Compares the independent GEE panel from 07a_export_prism_monthly_spotcheck.py
against the production prism_county_month.csv, county-month by
county-month, within a numeric tolerance.

- Reads the GEE export from dataCSV/PRISM/ (where the synced Drive file
  actually lands), and the production panel from
  dataCSV/PRISM/prism_county_month.csv. No Earth Engine calls, no
  aggregation -- pure comparison of two already-monthly panels.
- Left-joins the small GEE sample onto production (not an outer join), so
  the comparison only touches the ~480 sampled rows, not all ~1.7M
  production rows.
- A row passes only if its day count matches the calendar AND every
  variable is within tolerance (absolute or relative, whichever is
  looser) of production.
- Requires exactly one spot-check export file to be present, to avoid
  silently comparing against a stale prior run.
- Exits with a non-zero status if any sampled county-month fails, rather
  than just printing a warning.

Output: comparison/summary/failed CSVs under
dataCSV/PRISM/spot_check/monthly_gee/results/.
"""

from __future__ import annotations

import calendar
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd


# ---------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

PRODUCTION_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "prism_county_month.csv"
# Points at dataCSV/PRISM/ directly (not a spot_check/monthly_gee/raw/
# subfolder) -- matches where the synced Drive export actually landed on
# Kodama, alongside prism_county_month.csv. See module docstring.
SPOT_CHECK_RAW_DIR = REPO_ROOT / "dataCSV" / "PRISM"
RESULTS_DIR = (
    REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "monthly_gee" / "results"
)

SPOT_CHECK_PATTERN = "prism_spotcheck_monthly_*.csv"
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


# ---------------------------------------------------------------------
# Comparison configuration
# ---------------------------------------------------------------------

KEY_COLS = ["geoid", "year", "month"]

VALUE_COLS = [
    "ppt_total",
    "tmean_mean",
    "tmin_mean",
    "tmax_mean",
    "tdmean_mean",
    "vpdmin_mean",
    "vpdmax_mean",
]

# Same-source/same-estimand comparisons should be extremely close. These
# tolerances allow only tiny CSV/floating-point noise.
ABS_TOLERANCE = {
    "ppt_total": 1e-4,
    "tmean_mean": 1e-6,
    "tmin_mean": 1e-6,
    "tmax_mean": 1e-6,
    "tdmean_mean": 1e-6,
    "vpdmin_mean": 1e-6,
    "vpdmax_mean": 1e-6,
}

REL_TOLERANCE = 1e-8


# ---------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------

def find_single_spot_check_file() -> Path:
    """
    Require exactly one independent export in the raw folder.

    This avoids accidentally combining or comparing a stale prior run.
    """
    paths = sorted(SPOT_CHECK_RAW_DIR.glob(SPOT_CHECK_PATTERN))

    if not paths:
        raise FileNotFoundError(
            f"No file matching '{SPOT_CHECK_PATTERN}' found in "
            f"{SPOT_CHECK_RAW_DIR}. Run the GEE export script and place its "
            "CSV there first."
        )

    if len(paths) > 1:
        raise ValueError(
            "More than one spot-check export is present. Move old runs out of "
            f"{SPOT_CHECK_RAW_DIR} before comparing:\n"
            + "\n".join(f"  {p.name}" for p in paths)
        )

    return paths[0]


def read_csv_with_ids(path: Path) -> pd.DataFrame:
    """Read a panel while preserving leading zeros in geographic IDs."""
    return pd.read_csv(
        path,
        dtype={
            "geoid": str,
            "state_fips": str,
            "county_fips": str,
        },
    )


# ---------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------

def assert_unique_keys(df: pd.DataFrame, label: str) -> None:
    duplicates = df[df.duplicated(KEY_COLS, keep=False)]
    if not duplicates.empty:
        raise ValueError(
            f"{label} contains duplicate geoid/year/month keys:\n"
            f"{duplicates[KEY_COLS].drop_duplicates().to_string(index=False)}"
        )


def add_calendar_check(spot: pd.DataFrame) -> pd.DataFrame:
    """Check that GEE returned the expected number of daily images per month."""
    spot = spot.copy()
    spot["expected_days"] = spot.apply(
        lambda row: calendar.monthrange(
            int(row["year"]), int(row["month"])
        )[1],
        axis=1,
    )
    spot["n_days_matches_calendar"] = (
        spot["n_days"].astype(int) == spot["expected_days"]
    )
    return spot


# ---------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------

def compare_panels(
    spot: pd.DataFrame,
    production: pd.DataFrame,
) -> pd.DataFrame:
    """
    Left-join the small GEE spot-check panel onto production (spot as the
    driving table) and calculate variable-by-variable differences. Keeps
    just the ~480 sampled rows instead of all ~1.7M production rows, while
    still catching a sampled county-month missing from production via
    `_merge == "left_only"`.
    """
    production_cols = KEY_COLS + VALUE_COLS
    spot_cols = KEY_COLS + ["n_days", "dataset_types", "expected_days",
                            "n_days_matches_calendar"] + VALUE_COLS

    merged = spot[spot_cols].merge(
        production[production_cols],
        on=KEY_COLS,
        how="left",
        suffixes=("_gee", "_prod"),
        indicator=True,
    )

    both = merged["_merge"].eq("both")

    for col in VALUE_COLS:
        gee_col = f"{col}_gee"
        prod_col = f"{col}_prod"
        abs_col = f"{col}_abs_diff"
        rel_col = f"{col}_rel_diff"
        pass_col = f"{col}_passes"

        merged[abs_col] = (merged[gee_col] - merged[prod_col]).abs()

        denominator = np.maximum(
            merged[gee_col].abs(),
            merged[prod_col].abs(),
        )
        merged[rel_col] = np.where(
            denominator > 0,
            merged[abs_col] / denominator,
            0.0,
        )

        merged[pass_col] = (
            both
            & (
                (merged[abs_col] <= ABS_TOLERANCE[col])
                | (merged[rel_col] <= REL_TOLERANCE)
            )
        )

    pass_cols = [f"{col}_passes" for col in VALUE_COLS]
    merged["all_values_pass"] = merged[pass_cols].all(axis=1)
    merged["row_passes"] = (
        both
        & merged["n_days_matches_calendar"].fillna(False)
        & merged["all_values_pass"]
    )

    return merged


def build_summary(comparison: pd.DataFrame) -> pd.DataFrame:
    """Create a compact variable-level diagnostic summary."""
    rows = []

    for col in VALUE_COLS:
        abs_col = f"{col}_abs_diff"
        pass_col = f"{col}_passes"

        both = comparison[comparison["_merge"] == "both"]
        rows.append(
            {
                "variable": col,
                "rows_compared": len(both),
                "rows_failed": int((~both[pass_col]).sum()),
                "max_abs_diff": both[abs_col].max(),
                "mean_abs_diff": both[abs_col].mean(),
                "abs_tolerance": ABS_TOLERANCE[col],
                "relative_tolerance": REL_TOLERANCE,
            }
        )

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    if not PRODUCTION_PATH.exists():
        raise FileNotFoundError(
            f"Production monthly file not found: {PRODUCTION_PATH}"
        )

    spot_path = find_single_spot_check_file()

    print(f"Independent GEE monthly panel: {spot_path}")
    print(f"Production monthly panel:      {PRODUCTION_PATH}")

    spot = read_csv_with_ids(spot_path)
    production = read_csv_with_ids(PRODUCTION_PATH)

    assert_unique_keys(spot, "Independent GEE panel")
    assert_unique_keys(production, "Production panel")

    spot = add_calendar_check(spot)
    comparison = compare_panels(spot, production)
    summary = build_summary(comparison)

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    comparison_path = (
        RESULTS_DIR / f"prism_monthly_spotcheck_comparison_{RUN_TIMESTAMP}.csv"
    )
    summary_path = (
        RESULTS_DIR / f"prism_monthly_spotcheck_summary_{RUN_TIMESTAMP}.csv"
    )
    failed_path = (
        RESULTS_DIR / f"prism_monthly_spotcheck_failed_{RUN_TIMESTAMP}.csv"
    )

    comparison.to_csv(comparison_path, index=False)
    summary.to_csv(summary_path, index=False)

    matched_mask = comparison["_merge"] == "both"
    gee_only_mask = comparison["_merge"] == "left_only"
    # "Production-only" rows aren't in `comparison` (left join) -- get the
    # count directly from the two source frames instead.
    prod_only = len(production) - int(matched_mask.sum())

    # Failed = sampled row that didn't pass checks, or sampled row missing
    # from production entirely (gee_only).
    failed = comparison[(matched_mask & ~comparison["row_passes"]) | gee_only_mask].copy()
    if not failed.empty:
        failed.to_csv(failed_path, index=False)

    matched = int(matched_mask.sum())
    gee_only = int(gee_only_mask.sum())
    passed = int((matched_mask & comparison["row_passes"]).sum())

    print("\nComparison results")
    print("------------------")
    print(f"Matched county-month rows:              {matched:,}")
    print(f"GEE-only rows (missing from production): {gee_only:,}")
    print(
        f"Production-only rows (outside the sample, expected -- not "
        f"compared, not a failure): {prod_only:,}"
    )
    print(f"Rows passing all checks:                {passed:,}")
    print(f"Rows failing (mismatched or gee-only):  {len(failed):,}")

    print("\nVariable summary")
    print(summary.to_string(index=False))

    print(f"\nFull comparison saved to:\n  {comparison_path}")
    print(f"Summary saved to:\n  {summary_path}")

    if not failed.empty:
        print(f"Failed rows saved to:\n  {failed_path}")
        raise SystemExit(
            "\nSpot check found discrepancies among sampled county-months "
            "(mismatched values, or a sampled county-month missing from "
            "production). Review the failed-row file before treating the "
            "production panel as verified."
        )

    print(
        "\nPASS: every sampled county-month matched the independent GEE "
        "calculation within tolerance, and all day counts matched the "
        f"calendar. ({prod_only:,} production rows outside the sample "
        "were not compared, as expected.)"
    )


if __name__ == "__main__":
    main()
