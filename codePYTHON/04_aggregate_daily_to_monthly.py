"""
Aggregate daily county-level PRISM extracts to county-year-month.

Reads the daily CSV(s) produced by the PRISM extraction scripts
(01_test_prism_extract.py for the small-scale test; 02_extract_prism_county.py
for the full CONUS run) and collapses them to one row per county-year-month:
- ppt: summed over the month (monthly total precipitation)
- tmean, tmin, tmax: averaged over the month (mean of daily values)

Also flags any month whose daily rows mix PRISM 'dataset_type' vintages
(AN81 vs AN91). PRISM switches from AN81 to AN91 at the 2020/2021
boundary (AN91 uses a newer 1991-2020 baseline normals period instead
of 1981-2010) -- not provisional-vs-final, but still worth flagging so
a boundary month isn't silently averaged across two vintages without
anyone noticing.
"""

import glob
import os
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

# CHANGE: derive paths from this file's location instead of a
# hardcoded, machine-specific absolute path, so the script works
# regardless of who runs it or where the repo is cloned (matches the
# project's "single project-root variable" convention).
REPO_ROOT = Path(__file__).resolve().parents[1]

# Folder containing the daily county-level CSV(s) to aggregate -- this
# is where the 01_test_prism_extract.py Drive exports were downloaded
# to. Update this once 02_extract_prism_county.py's full-run output
# exists somewhere else.
INPUT_DIR = REPO_ROOT / "dataRAW" / "PRISM"

# Glob pattern matching the daily extraction CSVs within INPUT_DIR.
INPUT_PATTERN = "prism_county_daily_*.csv"

# CHANGE: write aggregated output to a dataBUILD/ folder alongside
# dataRAW/, rather than nested inside dataRAW/, so raw Earth Engine
# exports are never touched/mixed with derived output. This folder
# name is an assumption (not specified in CLAUDE.md/How We Work) --
# flag if you'd rather use a different convention.
OUTPUT_DIR = REPO_ROOT / "dataBUILD" / "PRISM"
OUTPUT_FILENAME = "prism_county_month.csv"

# Column names produced by 01_test_prism_extract.py / 02_extract_prism_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]


# ---------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------

def load_daily_extracts(input_dir: Path, pattern: str) -> pd.DataFrame:
    """Read and concatenate all daily extraction CSVs matching `pattern`."""
    paths = sorted(glob.glob(str(input_dir / pattern)))

    if not paths:
        raise FileNotFoundError(f"No files matching '{pattern}' found in {input_dir}")

    print(f"Found {len(paths)} daily extract file(s):")
    for path in paths:
        print(f"  - {os.path.basename(path)}")

    # dtype=str on the FIPS/geoid columns matters: without it, pandas
    # infers these as integers and silently drops leading zeros (e.g.
    # county_fips "005" -> 5, geoid "01001" -> 1001). Doesn't bite IL/IN
    # (17/18) in this test, but will corrupt merges for any state whose
    # FIPS code starts with 0 once the full CONUS extraction runs.
    frames = [
        pd.read_csv(
            path,
            parse_dates=["date"],
            dtype={"geoid": str, "state_fips": str, "county_fips": str},
        )
        for path in paths
    ]
    daily = pd.concat(frames, ignore_index=True)

    # Guard against accidentally loading overlapping/duplicate exports
    # (e.g. re-running the extraction and downloading both copies).
    duplicate_mask = daily.duplicated(subset=["geoid", "date"], keep=False)
    if duplicate_mask.any():
        n_dupes = (
            daily.loc[duplicate_mask, ["geoid", "date"]].drop_duplicates().shape[0]
        )
        raise ValueError(
            f"Found {n_dupes} geoid/date combinations duplicated across "
            "input files -- check for overlapping extracts before aggregating."
        )

    return daily


# ---------------------------------------------------------------------
# Aggregate
# ---------------------------------------------------------------------

def aggregate_to_month(daily: pd.DataFrame) -> pd.DataFrame:
    """Collapse a daily county-level PRISM table to county-year-month."""
    daily = daily.copy()
    daily["month"] = daily["date"].dt.month

    group_cols = ID_COLS + ["year", "month"]

    # Precipitation: monthly total. Temperature variables: monthly mean.
    monthly = daily.groupby(group_cols, as_index=False).agg(
        n_days=("date", "count"),
        ppt_total=("ppt", "sum"),
        tmean_mean=("tmean", "mean"),
        tmin_mean=("tmin", "mean"),
        tmax_mean=("tmax", "mean"),
    )

    # Flag months that mix PRISM vintages (e.g. Dec 2020, which straddles
    # the AN81 -> AN91 switch) so they can be spot-checked/documented
    # rather than silently averaged over without anyone noticing.
    dataset_types = (
        daily.groupby(group_cols)["dataset_type"]
        .agg(lambda values: ",".join(sorted(set(values))))
        .reset_index()
        .rename(columns={"dataset_type": "dataset_types"})
    )
    monthly = monthly.merge(dataset_types, on=group_cols, how="left")

    monthly = monthly.sort_values(group_cols).reset_index(drop=True)
    return monthly


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    daily = load_daily_extracts(INPUT_DIR, INPUT_PATTERN)
    print(f"\nLoaded {len(daily):,} daily county-day rows.")

    monthly = aggregate_to_month(daily)
    print(f"Aggregated to {len(monthly):,} county-month rows.")

    mixed_vintage = monthly[monthly["dataset_types"].str.contains(",")]
    if not mixed_vintage.empty:
        months = mixed_vintage[["year", "month"]].drop_duplicates()
        print(
            "\nNote: the following year-month(s) mix PRISM dataset "
            "vintages (AN81/AN91) -- expected at the 2020/2021 boundary:"
        )
        print(months.to_string(index=False))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / OUTPUT_FILENAME
    monthly.to_csv(output_path, index=False)
    print(f"\nSaved aggregated county-month table to:\n  {output_path}")


if __name__ == "__main__":
    main()
