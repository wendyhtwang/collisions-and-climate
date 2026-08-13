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
"""

import glob
import re
from pathlib import Path

import pandas as pd

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
# Paths
# ---------------------------------------------------------------------

def resolve_data_root(candidates):
    """Return the first existing directory from `candidates`, in order."""
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return path

    raise FileNotFoundError(
        "None of the candidate data roots exist on this machine: "
        f"{[str(c) for c in candidates]}. Add this machine's path to "
        "INPUT_DIR_CANDIDATES."
    )


def discover_input_files(input_dir: Path, pattern: str) -> list[Path]:
    """Return sorted paths to daily extract files matching `pattern`."""
    paths = sorted(Path(p) for p in glob.glob(str(input_dir / pattern)))

    if not paths:
        raise FileNotFoundError(f"No files matching '{pattern}' found in {input_dir}")

    return paths


def check_for_year_conflicts(paths: list[Path]) -> None:
    """
    Raise if any file doesn't match the expected <year> naming convention
    (e.g. a small-scale test file sitting in the same folder), or if more
    than one input file claims the same year (e.g. a rerun produced a
    second CSV) -- stops rather than silently guessing which file to use.
    """
    years_to_files: dict[str, list[Path]] = {}
    unparsed = []

    for path in paths:
        match = FILENAME_YEAR_RE.match(path.name)
        if not match:
            unparsed.append(path)
            continue
        years_to_files.setdefault(match.group(1), []).append(path)

    if unparsed:
        raise ValueError(
            "The following file(s) don't match the expected "
            "'era5_county_daily_<year>_<run_timestamp>.csv' naming "
            f"convention -- check before proceeding: {[p.name for p in unparsed]}"
        )

    conflicts = {year: fs for year, fs in years_to_files.items() if len(fs) > 1}
    if conflicts:
        lines = "\n".join(
            f"  {year}: {[p.name for p in fs]}" for year, fs in sorted(conflicts.items())
        )
        raise ValueError(
            "Multiple input files claim the same year -- resolve which "
            f"to keep before aggregating:\n{lines}"
        )

    found_years = {int(y) for y in years_to_files}
    missing = sorted(EXPECTED_YEARS - found_years)
    unexpected = sorted(found_years - EXPECTED_YEARS)
    if missing:
        print(f"Note: {len(missing)} expected year(s) not found among input files: {missing}")
    if unexpected:
        print(f"Note: {len(unexpected)} input year(s) outside the expected 1981-2025 range: {unexpected}")


# ---------------------------------------------------------------------
# Load + aggregate one year/file at a time, without holding all years of
# daily rows in memory at once.
# ---------------------------------------------------------------------

# Same known duplicate-row case as PRISM (18 WI counties with a
# source-data duplicate county feature -- see SCRIPT_OVERVIEW.md).
def resolve_duplicate_rows(daily: pd.DataFrame, duplicate_mask: pd.Series, path: Path) -> pd.DataFrame:
    """Handle geoid/date rows that appear more than once in a single file, w/o hard-erroring."""
    dup_rows = daily[duplicate_mask]

    # Per geoid/date, count distinct values (incl. NaN) in every non-key column; 
    # any column w/ >1 distinct value raises a conflict error.
    value_cols = [c for c in daily.columns if c not in ("geoid", "date")]
    n_distinct = dup_rows.groupby(["geoid", "date"])[value_cols].nunique(dropna=False)
    conflicting_keys = n_distinct.index[(n_distinct > 1).any(axis=1)]
    if len(conflicting_keys):
        conflicting_pairs = pd.DataFrame(conflicting_keys.tolist(), columns=["geoid", "date"])
        raise ValueError(
            f"{path.name}: found {len(conflicting_pairs)} geoid/date "
            "combination(s) with CONFLICTING duplicate rows (same "
            "geoid+date, but values disagree elsewhere) -- this is NOT "
            "the known byte-identical-duplicate case and needs manual "
            f"review before aggregating:\n{conflicting_pairs.to_string(index=False)}"
        )

    # Everything remaining is a confirmed byte-identical duplicate --
    # safe to collapse to one row per geoid/date.
    n_pairs_affected = dup_rows[["geoid", "date"]].drop_duplicates().shape[0]
    n_rows_dropped = int(duplicate_mask.sum()) - n_pairs_affected
    affected_geoids = sorted(dup_rows["geoid"].unique())
    print(
        f"  Note: {path.name} had {n_rows_dropped} exact-duplicate row(s) "
        f"across {n_pairs_affected} geoid/date combination(s) -- confirmed "
        f"byte-identical, dropped automatically. Affected geoid(s): {affected_geoids}"
    )

    return daily.drop_duplicates(subset=["geoid", "date"], keep="first")


def load_daily_extract(path: Path) -> pd.DataFrame:
    """Read one daily extraction CSV (one calendar year)."""
    # dtype=str on the FIPS/geoid columns matters: without it, pandas
    # infers these as integers and silently drops leading zeros (e.g.
    # county_fips "005" -> 5, geoid "01001" -> 1001), which would corrupt
    # merges for any state whose FIPS code starts with 0.
    daily = pd.read_csv(
        path,
        parse_dates=["date"],
        dtype={"geoid": str, "state_fips": str, "county_fips": str},
    )

    duplicate_mask = daily.duplicated(subset=["geoid", "date"], keep=False)
    if duplicate_mask.any():
        daily = resolve_duplicate_rows(daily, duplicate_mask, path)

    return daily


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
# Completeness check: flag county-months with fewer/more days than the
# calendar expects (leap years included), so partial data isn't silently
# aggregated as if it were a full month.
# ---------------------------------------------------------------------

def flag_incomplete_months(monthly: pd.DataFrame) -> pd.DataFrame:
    """Add an `is_incomplete` column: day count vs. expected calendar days."""
    monthly = monthly.copy()

    monthly["expected_days"] = pd.PeriodIndex.from_fields(
        year=monthly["year"].astype(int), month=monthly["month"].astype(int), freq="M"
    ).days_in_month
    monthly["is_incomplete"] = monthly["n_days"] != monthly["expected_days"]
    return monthly


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    input_dir = resolve_data_root(INPUT_DIR_CANDIDATES)
    print(f"Reading daily extracts from: {input_dir}")

    paths = discover_input_files(input_dir, INPUT_PATTERN)
    print(f"Found {len(paths)} daily extract file(s).")
    check_for_year_conflicts(paths)

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
