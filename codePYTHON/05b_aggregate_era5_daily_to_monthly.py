"""
Aggregates the daily county-level ERA5-Land CSVs into one county-year-month
panel (the ERA5 counterpart to 05_aggregate_daily_to_monthly.py's PRISM
output): precip_mm and snowfall_mm summed to monthly totals, all other
variables averaged.

- precip_mm/snowfall_mm are summed; tmean_c, tmin_c, tmax_c, dewpoint_c,
  skin_temp_c, wind_speed_10m, snow_depth, surface_pressure are averaged --
  snow_depth is a stock (snow currently on the ground), not a flux, so a
  mean is the meaningful summary, not a sum.
- No dataset-vintage flag here: unlike PRISM (AN81/AN91), ERA5-Land is a
  single reanalysis product with no vintage boundary in this period.
- Flags, and writes to a separate file, any county-month whose day count
  doesn't match the expected calendar days, rather than silently
  aggregating a partial month -- same completeness check as production
  PRISM.
- Drops confirmed byte-identical duplicate rows automatically (same known
  WI-county case documented for PRISM -- see SCRIPT_OVERVIEW.md); raises
  an error instead if any non-key column disagrees within a geoid/date
  group, since that needs a human look.
- Reads one year/file at a time rather than loading all 45 years into
  memory at once.
- File discovery, year-conflict checking, duplicate-row resolution, and
  the completeness check are shared with 05/06 -- see aggregation_utils.py.
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

# Where the daily county-level CSVs from 04_extract_era5_county.py live.
# First existing candidate wins -- add this machine's path here if neither
# matches (e.g. a different mount point). Kodama is listed first since
# that's where the full CONUS run was generated; dataRAW/ERA5 is the
# personal dev repo fallback (e.g. a partial local copy for testing).
INPUT_DIR_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/ERA5/extracted/county_daily_year",  # Kodama server
    REPO_ROOT / "dataRAW" / "ERA5",  # personal dev repo fallback
]

# Glob pattern matching the daily extraction CSVs within INPUT_DIR. Only
# matches the full-run naming convention from 04_extract_era5_county.py:
# era5_county_daily_<year>_<run_timestamp>.csv. Small-scale test files in
# the dev-repo fallback don't match this and are caught by
# check_for_year_conflicts() below rather than silently included.
INPUT_PATTERN = "era5_county_daily_*.csv"

# Expected ERA5 extraction years, per 04_extract_era5_county.py's YEARS
# config (1981-2025 inclusive = 45 years). Used only to report missing/
# unexpected years found among the input files -- not to filter them.
EXPECTED_YEARS = set(range(1981, 2026))

OUTPUT_DIR = REPO_ROOT / "dataCSV" / "ERA5"
OUTPUT_FILENAME = "era5_county_month.csv"
FLAGGED_INCOMPLETE_FILENAME = "era5_county_month_incomplete_flagged.csv"

# Column names produced by 04_extract_era5_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Aggregation for each ERA5-Land band:
# precip_mm/snowfall_mm are monthly totals; everything else (temperatures,
# wind speed, snow depth, surface pressure) is a monthly mean.
SUM_VARS = ["precip_mm", "snowfall_mm"]
MEAN_VARS = [
    "tmean_c",
    "tmin_c",
    "tmax_c",
    "dewpoint_c",
    "skin_temp_c",
    "wind_speed_10m",
    "snow_depth",
    "surface_pressure",
]

# Filename pattern for the full-run naming convention, used to pull the
# year out of the filename for the cross-file duplicate-year check before
# any file is read.
FILENAME_YEAR_RE = re.compile(r"^era5_county_daily_(\d{4})_")


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
        naming_hint="era5_county_daily_<year>_<run_timestamp>.csv",
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
