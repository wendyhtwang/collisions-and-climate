"""
Aggregates the daily county-level PRISM CSVs into one county-year-month
panel (the final PRISM output): ppt summed to a monthly total, all other
variables averaged.

- ppt is summed; tmean, tmin, tmax, tdmean, vpdmin, vpdmax are averaged --
  matches PRISM's own documented convention (PRISM notes monthly grids
  aren't a pure average of the dailies, since the monthlies use more
  stations than the dailies).
- Flags (doesn't silently average over) any county-month mixing PRISM's
  AN81/AN91 vintages, which happens at the 2020/2021 boundary.
- Flags, and writes to a separate file, any county-month whose day count
  doesn't match the expected calendar days, rather than silently
  aggregating a partial month.
- Drops confirmed byte-identical duplicate rows automatically (known case:
  18 WI counties -- see SCRIPT_OVERVIEW.md); raises an error instead if any
  non-key column disagrees within a geoid/date group, since that needs a
  human look.
- Reads one year/file at a time rather than loading all 45 years into
  memory at once.
- File discovery, year-conflict checking, duplicate-row resolution, and
  the completeness check are shared with 05b/06 -- see aggregation_utils.py.
"""

import re
from pathlib import Path

import pandas as pd

from aggregation_utils import (
    check_for_year_conflicts,
    discover_input_files,
    flag_incomplete_months,
    load_daily_extract,
    resolve_data_root,
)

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

# Where the daily county-level CSVs from 02_extract_prism_county.py live.
# First existing candidate wins -- add this machine's path here if neither
# matches (e.g. a different mount point). Kodama is listed first since
# that's where the full 46-file run was generated; dataRAW/PRISM is the
# personal dev repo fallback (e.g. a partial local copy for testing).
INPUT_DIR_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/PRISM/extracted/county_daily_year",  # Kodama server
    REPO_ROOT / "dataRAW" / "PRISM",  # personal dev repo fallback
]

# Glob pattern matching the daily extraction CSVs within INPUT_DIR. Only
# matches files directly in INPUT_DIR (not the dataRAW/PRISM/test/
# subfolder used by the small-scale prototype), and only the full-run
# naming convention from 02_extract_prism_county.py:
# prism_county_daily_<year>_<run_timestamp>.csv
INPUT_PATTERN = "prism_county_daily_*.csv"

# Expected PRISM extraction years, per 02_extract_prism_county.py's YEARS
# config (1981-2025 inclusive = 45 years). Used only to report missing/
# unexpected years found among the input files -- not to filter them.
EXPECTED_YEARS = set(range(1981, 2026))

OUTPUT_DIR = REPO_ROOT / "dataCSV" / "PRISM"
OUTPUT_FILENAME = "prism_county_month.csv"
FLAGGED_INCOMPLETE_FILENAME = "prism_county_month_incomplete_flagged.csv"

# Column names produced by 02_extract_prism_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Aggregation for each PRISM band:
# precipitation is a monthly total,
# everything else is a monthly mean.
SUM_VARS = ["ppt"]
MEAN_VARS = ["tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]

# Filename pattern for the full-run naming convention, used to pull the
# year out of the filename for the cross-file duplicate-year check before
# any file is read.
FILENAME_YEAR_RE = re.compile(r"^prism_county_daily_(\d{4})_")


# ---------------------------------------------------------------------
# Aggregate one file's daily county rows to county-year-month
# ---------------------------------------------------------------------

def aggregate_file_to_month(daily: pd.DataFrame) -> pd.DataFrame:
    """Collapse one file's daily county rows to county-year-month."""
    daily = daily.copy()
    daily["month"] = daily["date"].dt.month

    group_cols = ID_COLS + ["year", "month"]

    agg_kwargs = {"n_days": ("date", "count")}
    agg_kwargs.update({f"{v}_total": (v, "sum") for v in SUM_VARS})
    agg_kwargs.update({f"{v}_mean": (v, "mean") for v in MEAN_VARS})

    monthly = daily.groupby(group_cols, as_index=False).agg(**agg_kwargs)

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

    return monthly


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    input_dir = resolve_data_root(INPUT_DIR_CANDIDATES)
    print(f"Reading daily extracts from: {input_dir}")

    paths = discover_input_files(input_dir, INPUT_PATTERN)
    print(f"Found {len(paths)} daily extract file(s).")
    check_for_year_conflicts(
        paths, FILENAME_YEAR_RE, EXPECTED_YEARS,
        naming_hint="prism_county_daily_<year>_<run_timestamp>.csv",
    )

    monthly_frames = []
    total_daily_rows = 0

    for i, path in enumerate(paths, start=1):
        print(f"  [{i}/{len(paths)}] {path.name}")
        daily = load_daily_extract(path)
        total_daily_rows += len(daily)
        monthly_frames.append(aggregate_file_to_month(daily))
        del daily  # free the daily rows before loading the next year/file

    monthly = pd.concat(monthly_frames, ignore_index=True)
    group_cols = ID_COLS + ["year", "month"]
    monthly = monthly.sort_values(group_cols).reset_index(drop=True)

    print(f"\nLoaded {total_daily_rows:,} daily county-day rows across {len(paths)} file(s).")
    print(f"Aggregated to {len(monthly):,} county-month rows.")

    monthly = flag_incomplete_months(monthly)

    mixed_vintage = monthly[monthly["dataset_types"].str.contains(",")]
    if not mixed_vintage.empty:
        months = mixed_vintage[["year", "month"]].drop_duplicates()
        print(
            "\nNote: the following year-month(s) mix PRISM dataset "
            "vintages (AN81/AN91) -- expected at the 2020/2021 boundary:"
        )
        print(months.to_string(index=False))

    incomplete = monthly[monthly["is_incomplete"]]
    if not incomplete.empty:
        print(
            f"\nWarning: {len(incomplete):,} county-month row(s) have a day count "
            "that doesn't match the calendar days expected for that month -- "
            f"see {FLAGGED_INCOMPLETE_FILENAME}."
        )
    else:
        print("\nNo incomplete county-months found (n_days matches calendar days everywhere).")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_path = OUTPUT_DIR / OUTPUT_FILENAME
    monthly.to_csv(output_path, index=False)
    print(f"\nSaved aggregated county-month table to:\n  {output_path}")

    if not incomplete.empty:
        flagged_path = OUTPUT_DIR / FLAGGED_INCOMPLETE_FILENAME
        incomplete.to_csv(flagged_path, index=False)
        print(f"Saved incomplete-month rows for review to:\n  {flagged_path}")


if __name__ == "__main__":
    main()
