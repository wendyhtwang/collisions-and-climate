"""
Aggregate daily county-level PRISM extracts to county-year-month.
No Earth Engine (earthengine-api) required.
Checks for duplicate geoid/date rows, flagging conflicting-year files, incomplete months, etc.

Reads the daily CSVs produced by 02_extract_prism_county.py (one file per
calendar year, ~3,109 CONUS counties x ~365 days x 7 bands) and collapses
them to one row per county-year-month:
- ppt: summed over the month (monthly total precipitation)
- tmean, tmin, tmax, tdmean, vpdmin, vpdmax: averaged over the month

Also still flags any month whose daily rows mix PRISM 'dataset_type'
vintages (AN81 vs AN91). PRISM switches from AN81 to AN91 at the 2020/2021
boundary (AN91 uses a newer 1991-2020 baseline normals period instead of
1981-2010) -- not provisional-vs-final, but still worth flagging so a
boundary month isn't silently averaged across two vintages without anyone
noticing.

PROPOSED CHANGE (this file, not yet copied into 04_aggregate_daily_to_monthly.py):
load_daily_extract() no longer hard-errors on every geoid/date duplicate.
See resolve_duplicate_rows()'s docstring below for the full reasoning --
short version: a reproducible, confirmed-byte-identical duplicate (18 WI
counties, both the 2020 and 2021 full-CONUS exports; root cause
investigated across several diagnostic scripts on 2026-08-05 but never
conclusively pinned down) is now dropped automatically and logged,
instead of blocking the whole run. Any duplicate pair whose values
actually DISAGREE still hard-fails, same as before -- that's a different,
more dangerous case this change does not paper over.
"""

import calendar
import glob
import re
from pathlib import Path

import pandas as pd

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
    "/mnt/data_f/AnimalCollisionsWeatherData/PRISM",  # Kodama server
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

OUTPUT_DIR = REPO_ROOT / "dataBUILD" / "PRISM"
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
    Raise if more than one input file claims the same year.

    Filenames follow prism_county_daily_<year>_<run_timestamp>.csv (one
    export task per calendar year). Two files sharing a year most likely
    means a rerun produced a second CSV for a year already extracted --
    silently picking one (e.g. "last sorted") risks dropping a valid
    export or keeping a stale one, so this stops and asks rather than
    guessing which to use.
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
            "'prism_county_daily_<year>_<run_timestamp>.csv' naming "
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
# Load + aggregate (one year/file at a time,
# without holding all 46 years of daily rows (~9GB total) in memory (a single DataFrame) at once.
# ---------------------------------------------------------------------

def resolve_duplicate_rows(daily: pd.DataFrame, duplicate_mask: pd.Series, path: Path) -> pd.DataFrame:
    """
    Handle geoid/date rows that appear more than once in a single file.

    CHANGE: this used to be a hard error on ANY geoid/date duplicate,
    forcing a manual look before aggregating could proceed -- a
    reasonable default for a case nobody had characterized yet. Since
    then, a reproducible instance was investigated in detail (18
    Wisconsin counties, present identically in both the 2020 and 2021
    full-CONUS exports; see the 02c-02h diagnostic scripts and the
    2026-08-05 team discussion): every duplicate row in that case is
    byte-for-byte identical to its sibling -- same
    ppt/tmean/tmin/tmax/tdmean/vpdmin/vpdmax/dataset_type values, not
    just the same geoid+date key. The root cause was never conclusively
    pinned down (ruled out: duplicate TIGER county features, tileScale
    artifacts, multi-part county geometries; gee_extract_utils.
    get_counties() itself gave contradictory duplicate counts across two
    different Earth Engine query shapes -- stable/repeatable within each
    shape, but disagreeing with each other -- which looks like a
    platform-level quirk rather than something fixable in this repo).

    Given that a byte-identical duplicate is unambiguous to resolve
    (keeping either copy is correct -- there's no question of which
    value is "right"), it's safe to drop these automatically here rather
    than block the entire aggregation run on an upstream mystery that
    may never get a clean answer -- AS LONG AS every dropped case is
    verified identical first, and logged rather than silently discarded.

    Any duplicate geoid/date pair whose rows are NOT byte-identical (the
    same key with genuinely different values in some other column) still
    hard-fails, exactly as before. That's a different, more dangerous
    failure mode -- silently picking one of two disagreeing values would
    be a real correctness risk, not a cosmetic cleanup -- and this change
    deliberately does not touch that path.
    """
    dup_rows = daily[duplicate_mask]

    # Rows that share a geoid/date key but are NOT full-row duplicates
    # (some other column disagrees) -- the dangerous case that still
    # needs a human, not an automatic drop.
    conflicting_rows = dup_rows[~dup_rows.duplicated(keep=False)]
    if not conflicting_rows.empty:
        conflicting_pairs = conflicting_rows[["geoid", "date"]].drop_duplicates()
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
# Completeness check: flag any county-month whose day count
#    doesn't match the calendar days expected for that month/year (leap
#    years included), to avoid averaging/summing over incomplete-month data.
# ---------------------------------------------------------------------

def flag_incomplete_months(monthly: pd.DataFrame) -> pd.DataFrame:
    """
    Add an `is_incomplete` column: True if a county-month's day count
    doesn't match the calendar days expected for that year/month.

    Catches partial-month data (e.g. a truncated export, missing daily
    rows) that would otherwise be silently summed/averaged as if it were
    a full month.
    """
    monthly = monthly.copy()
    expected_days = monthly.apply(
        lambda row: calendar.monthrange(int(row["year"]), int(row["month"]))[1], axis=1
    )
    monthly["expected_days"] = expected_days
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
