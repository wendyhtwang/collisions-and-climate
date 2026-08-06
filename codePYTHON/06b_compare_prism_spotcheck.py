"""
Stage 2 of 2: aggregate the daily PRISM spot-check exports (from
06_verify_against_published.py, synced from Drive into RAW_DAILY_DIR) to
county-year-month, and compare them to the production
dataCSV/PRISM/prism_county_month.csv (built by 04_aggregate_daily_to_monthly.py).

Does NO Earth Engine calls -- pure local pandas, same as
04_aggregate_daily_to_monthly.py. Run this after 06's export tasks have
completed AND the resulting CSVs have been synced from Drive into
RAW_DAILY_DIR (see 06's "Next steps" log message for the exact path).

METHOD: aggregates via 04_aggregate_daily_to_monthly.py's own
aggregate_file_to_month() and resolve_duplicate_rows() (imported by file
path, since 04's filename starts with a digit) -- not a reimplementation
-- so this spot check uses the exact same monthly-aggregation and
duplicate-row handling as production. Any divergence found below
therefore reflects a real GEE-vs-pipeline difference, not a second,
possibly-inconsistent reimplementation of the same math.

OUTPUT: writes ONLY under dataCSV/PRISM/spot_check/ -- never touches
dataCSV/PRISM/prism_county_month.csv itself.
"""

import importlib.util
import re
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check"
RAW_DAILY_DIR = OUTPUT_DIR / "raw_daily"  # must match 06_verify_against_published.py

# Matches the filename convention 06_verify_against_published.py exports:
# prism_spotcheck_daily_<year>_<run_timestamp>.csv
INPUT_PATTERN = "prism_spotcheck_daily_*.csv"
FILENAME_YEAR_RE = re.compile(r"^prism_spotcheck_daily_(\d{4})_")

AGGREGATE_MODULE_PATH = REPO_ROOT / "codePYTHON" / "04_aggregate_daily_to_monthly.py"

# Flag a comparison row if any variable's absolute percent difference
# exceeds this. Differences below this are treated as expected
# floating-point/rounding noise, per verify_prism_gee_console.js's
# console-check guidance ("first or second decimal place... worth
# investigating").
TOLERANCE_PCT = 0.5

RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


# ---------------------------------------------------------------------
# Reuse 04_aggregate_daily_to_monthly.py's own aggregation + dedup logic
# ---------------------------------------------------------------------

def load_aggregate_module():
    """
    Import 04_aggregate_daily_to_monthly.py by file path (a plain `import`
    won't work -- its filename starts with a digit, which isn't a legal
    Python module name). See this script's docstring for why reusing its
    functions -- rather than reimplementing them here -- matters.
    """
    spec = importlib.util.spec_from_file_location(
        "aggregate_daily_to_monthly", AGGREGATE_MODULE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------
# Load + aggregate the synced spot-check exports
# ---------------------------------------------------------------------

def discover_spotcheck_files():
    paths = sorted(RAW_DAILY_DIR.glob(INPUT_PATTERN))
    if not paths:
        raise FileNotFoundError(
            f"No files matching '{INPUT_PATTERN}' found in {RAW_DAILY_DIR} -- "
            "run 06_verify_against_published.py first, then sync/download "
            "its Drive exports into this folder."
        )
    return paths


def warn_on_repeat_years(paths):
    """
    Print (not raise -- this is a lower-stakes diagnostic tool, not
    production) if more than one file claims the same year, e.g. leftover
    files from an earlier spot-check run in the same folder.
    """
    years_seen = {}
    for path in paths:
        match = FILENAME_YEAR_RE.match(path.name)
        year = match.group(1) if match else "(unparsed)"
        years_seen.setdefault(year, []).append(path.name)

    repeats = {y: fs for y, fs in years_seen.items() if len(fs) > 1}
    if repeats:
        print(
            "Warning: more than one file claims the same year -- if these "
            "are from different runs, clear stale files from "
            f"{RAW_DAILY_DIR} before comparing, or rows will be double-"
            f"counted:\n{repeats}"
        )


def load_and_aggregate(aggregate_module):
    """Load each synced daily export, dedupe, and aggregate to monthly -- one file/year at a time."""
    paths = discover_spotcheck_files()
    warn_on_repeat_years(paths)

    monthly_frames = []
    for path in paths:
        print(f"  {path.name}")
        daily = pd.read_csv(
            path,
            parse_dates=["date"],
            dtype={"geoid": str, "state_fips": str, "county_fips": str},
        )

        duplicate_mask = daily.duplicated(subset=["geoid", "date"], keep=False)
        if duplicate_mask.any():
            daily = aggregate_module.resolve_duplicate_rows(daily, duplicate_mask, path)

        monthly_frames.append(aggregate_module.aggregate_file_to_month(daily))

    monthly = pd.concat(monthly_frames, ignore_index=True)
    return monthly.sort_values(aggregate_module.ID_COLS + ["year", "month"]).reset_index(drop=True)


# ---------------------------------------------------------------------
# Compare to production output
# ---------------------------------------------------------------------

def compare_to_production(spot_check_monthly, aggregate_module):
    """
    Merge the GEE-computed spot-check panel against the production
    dataCSV/PRISM/prism_county_month.csv on geoid/year/month, and compute
    absolute + percent differences for every aggregated variable.

    Reports (but doesn't silently drop) county-months present on one side
    only -- e.g. a sampled county-year not yet extracted in production, or
    vice versa -- rather than letting an outer-join gap quietly disappear.
    """
    prod_path = aggregate_module.OUTPUT_DIR / aggregate_module.OUTPUT_FILENAME
    if not prod_path.exists():
        raise FileNotFoundError(
            f"Production monthly file not found at {prod_path} -- run "
            "04_aggregate_daily_to_monthly.py first."
        )

    id_cols = aggregate_module.ID_COLS
    dtype_map = {c: str for c in id_cols}
    production = pd.read_csv(prod_path, dtype=dtype_map)

    key_cols = id_cols + ["year", "month"]
    compare_cols = (
        [f"{v}_total" for v in aggregate_module.SUM_VARS]
        + [f"{v}_mean" for v in aggregate_module.MEAN_VARS]
    )

    merged = spot_check_monthly.merge(
        production[key_cols + compare_cols],
        on=key_cols,
        how="outer",
        suffixes=("_gee", "_prod"),
        indicator=True,
    )

    gee_only = merged[merged["_merge"] == "left_only"]
    prod_only = merged[merged["_merge"] == "right_only"]
    if not gee_only.empty:
        print(
            f"\nNote: {len(gee_only)} sampled county-month(s) have a GEE "
            "spot-check value but no matching row in production output "
            "(not yet extracted/aggregated there?):"
        )
        print(gee_only[key_cols].to_string(index=False))
    if not prod_only.empty:
        print(
            f"\nNote: {len(prod_only)} sampled county-month(s) exist in "
            "production but returned no GEE spot-check row (unexpected -- "
            "investigate before trusting this comparison)."
        )

    both = merged[merged["_merge"] == "both"].copy()

    for col in compare_cols:
        gee_col, prod_col = f"{col}_gee", f"{col}_prod"
        abs_diff_col, pct_diff_col = f"{col}_abs_diff", f"{col}_pct_diff"
        both[abs_diff_col] = (both[gee_col] - both[prod_col]).abs()
        # Percent difference is unstable/misleading near zero (e.g. a
        # near-zero monthly ppt_total, or a temperature mean near 0degC) --
        # leave it NaN there rather than reporting a meaningless huge
        # percentage; the abs_diff column still shows the real-units gap.
        near_zero = both[prod_col].abs() < 1e-6
        both[pct_diff_col] = np.where(
            near_zero, np.nan, 100 * both[abs_diff_col] / both[prod_col].abs()
        )

    pct_diff_cols = [f"{c}_pct_diff" for c in compare_cols]
    both["max_pct_diff"] = both[pct_diff_cols].max(axis=1, skipna=True)
    both["flagged"] = both["max_pct_diff"] > TOLERANCE_PCT

    return both.drop(columns="_merge").reset_index(drop=True)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    aggregate_module = load_aggregate_module()

    print(f"Reading synced spot-check exports from: {RAW_DAILY_DIR}")
    spot_check_monthly = load_and_aggregate(aggregate_module)
    print(f"Aggregated to {len(spot_check_monthly):,} county-month row(s).")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    spot_check_path = OUTPUT_DIR / f"prism_gee_spotcheck_monthly_{RUN_TIMESTAMP}.csv"
    spot_check_monthly.to_csv(spot_check_path, index=False)
    print(f"Saved GEE-computed spot-check panel to: {spot_check_path}")

    comparison = compare_to_production(spot_check_monthly, aggregate_module)
    comparison_path = OUTPUT_DIR / f"prism_gee_spotcheck_comparison_{RUN_TIMESTAMP}.csv"
    comparison.to_csv(comparison_path, index=False)
    print(f"Saved comparison to: {comparison_path}")

    flagged = comparison[comparison["flagged"]]
    print(
        f"\n{len(comparison)} county-month(s) compared; {len(flagged)} flagged "
        f"(max percent difference across variables > {TOLERANCE_PCT}%)."
    )
    if not flagged.empty:
        print("\nFlagged rows:")
        print(
            flagged[aggregate_module.ID_COLS + ["year", "month", "max_pct_diff"]]
            .to_string(index=False)
        )
    else:
        print(
            "No rows exceeded the tolerance -- production output matches the "
            "independent GEE computation for this sample."
        )


if __name__ == "__main__":
    main()
