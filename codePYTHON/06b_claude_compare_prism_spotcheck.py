"""
Stage 2 of 2: aggregate the daily PRISM spot-check exports (from
06_verify_against_published.py, synced from Drive into RAW_DAILY_DIR) to
county-year-month, and compare them to the production
dataCSV/PRISM/prism_county_month.csv (built by 04_aggregate_daily_to_monthly.py).

Does NO Earth Engine calls -- pure local pandas, same as
04_aggregate_daily_to_monthly.py. Run this after 06's export tasks have
completed AND the resulting CSVs have been synced from Drive into
RAW_DAILY_DIR (see 06's "Next steps" log message for the exact path).

METHOD -- CHANGE (2026-08-06): the monthly aggregation below (sum ppt,
mean everything else, grouped by county-year-month) is a FROM-SCRATCH
reimplementation, deliberately NOT calling 04_aggregate_daily_to_monthly.py's
aggregate_file_to_month(). Originally it did call that function directly,
on the theory that reusing production's exact logic would rule out a
second, possibly-divergent reimplementation. That reasoning had a real
gap: if aggregate_file_to_month() itself has a bug (wrong sum/mean split,
wrong month/groupby logic, mishandled duplicates interacting badly with
the groupby, etc.), calling it here would reproduce that same bug in the
spot-check too -- the comparison would report "no discrepancy" even
though the underlying logic is wrong. Testing a function against a
second call to itself only proves the file currently on disk matches
what the code produces RIGHT NOW; it proves nothing about whether that
code is CORRECT. (verify_prism_gee_console.js's original manual
county-month checks avoided this from the start -- they compute the
monthly sum/mean via GEE's own ee.Reducer.sum()/.mean() in JavaScript,
not by calling the Python aggregation function -- this file's SUM_VARS/
MEAN_VARS split and groupby logic are re-derived from the same domain
reasoning (precipitation is a monthly total; everything else is a
monthly mean) rather than copied from 04's config, for the same reason.

Duplicate-row handling (resolve_duplicate_rows()) is still imported from
04_aggregate_daily_to_monthly.py, NOT reimplemented -- that's data
hygiene (dropping confirmed byte-identical export duplicates), not the
aggregation math actually being spot-checked, so reusing it doesn't
reintroduce the "testing code against itself" problem above. The
production file's location (OUTPUT_DIR/OUTPUT_FILENAME) is also read
from that module rather than hardcoded here, so this script can't drift
out of sync with wherever 04 actually writes its output -- again just a
path, not aggregation logic.

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

# County/state identifier columns -- matches the schema every extraction
# script in this repo uses (geeutil.ID_COLS). Defined fresh here rather
# than imported, same independence reasoning as SUM_VARS/MEAN_VARS below
# (this one's just column names, not math, so the risk is low either way,
# but keeping this script's aggregation step free of any import from
# 04_aggregate_daily_to_monthly.py makes the independence easy to audit
# at a glance).
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Re-derived from domain knowledge (precipitation is a monthly total;
# temperature/humidity/pressure-type variables are monthly means) -- NOT
# copied from 04_aggregate_daily_to_monthly.py's SUM_VARS/MEAN_VARS. See
# module docstring for why that distinction matters here.
SUM_VARS = ["ppt"]
MEAN_VARS = ["tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]

# Flag a comparison row if any variable's absolute percent difference
# exceeds this. Differences below this are treated as expected
# floating-point/rounding noise, per verify_prism_gee_console.js's
# console-check guidance ("first or second decimal place... worth
# investigating").
TOLERANCE_PCT = 0.5

RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


# ---------------------------------------------------------------------
# Only used for duplicate-row dedup and locating the production file --
# NOT for the aggregation math itself. See module docstring.
# ---------------------------------------------------------------------

def load_aggregate_module():
    """
    Import 04_aggregate_daily_to_monthly.py by file path (a plain `import`
    won't work -- its filename starts with a digit, which isn't a legal
    Python module name). Used here only for resolve_duplicate_rows() and
    OUTPUT_DIR/OUTPUT_FILENAME -- the monthly aggregation itself is
    reimplemented independently below, on purpose.
    """
    spec = importlib.util.spec_from_file_location(
        "aggregate_daily_to_monthly", AGGREGATE_MODULE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------
# Independent monthly aggregation
# ---------------------------------------------------------------------

def aggregate_to_month(daily: pd.DataFrame) -> pd.DataFrame:
    """
    Collapse one file's daily county rows to county-year-month: ppt
    summed, everything else averaged, grouped by county-year-month.

    Written from scratch here rather than calling
    04_aggregate_daily_to_monthly.py's aggregate_file_to_month() -- see
    this module's docstring for why that matters for a spot check meant
    to catch bugs in that function, not just reproduce them.
    """
    daily = daily.copy()
    daily["month"] = daily["date"].dt.month

    group_cols = ID_COLS + ["year", "month"]

    monthly = daily.groupby(group_cols, as_index=False).agg(
        n_days=("date", "count"),
        **{f"{v}_total": (v, "sum") for v in SUM_VARS},
        **{f"{v}_mean": (v, "mean") for v in MEAN_VARS},
    )
    return monthly


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

        monthly_frames.append(aggregate_to_month(daily))

    monthly = pd.concat(monthly_frames, ignore_index=True)
    return monthly.sort_values(ID_COLS + ["year", "month"]).reset_index(drop=True)


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

    dtype_map = {c: str for c in ID_COLS}
    production = pd.read_csv(prod_path, dtype=dtype_map)

    key_cols = ID_COLS + ["year", "month"]
    compare_cols = (
        [f"{v}_total" for v in SUM_VARS]
        + [f"{v}_mean" for v in MEAN_VARS]
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
            flagged[ID_COLS + ["year", "month", "max_pct_diff"]]
            .to_string(index=False)
        )
    else:
        print(
            "No rows exceeded the tolerance -- production output matches the "
            "independent GEE computation for this sample."
        )


if __name__ == "__main__":
    main()
