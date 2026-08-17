"""
Shared validation/IO helpers for the daily-to-monthly aggregation scripts --
05_aggregate_prism_daily_to_monthly.py, 05b_aggregate_era5_daily_to_monthly.py,
and 06_build_derived_weather_vars.py. All three read one year's daily county
extract at a time and roll it up to county-year-month, so they were
independently carrying near-identical copies of the same data-quality
checks: locating/validating input files, resolving the known WI-county
duplicate rows, and flagging incomplete months. Extracted here so a fix or
review of this logic only has to happen once -- see SCRIPT_OVERVIEW.md.

Dataset-specific logic (which columns to sum vs. average, unit conversions,
derived variables) stays in the calling script; this module only assumes
the columns every daily extract shares (`geoid`, `date`, `year`, `month`).
Mirrors gee_extract_utils.py's role for the extraction-stage scripts
(00/02/02b/03/04/04b) -- this is the equivalent shared module for the
aggregation stage.
"""

import glob
from pathlib import Path

import pandas as pd


# ---------------------------------------------------------------------
# Paths / file discovery
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
        "the candidate list in the calling script."
    )


def discover_input_files(input_dir, pattern):
    """Return sorted paths to daily extract files matching `pattern`."""
    paths = sorted(Path(p) for p in glob.glob(str(Path(input_dir) / pattern)))

    if not paths:
        raise FileNotFoundError(f"No files matching '{pattern}' found in {input_dir}")

    return paths


def check_for_year_conflicts(paths, filename_year_re, expected_years, *, label=None, naming_hint=None):
    """
    Raise if any file doesn't match the expected <year> naming convention
    (e.g. a small-scale test file sitting in the same folder), or if more
    than one input file claims the same year -- stops rather than silently
    guessing which file to use.

    `label`, if given, prefixes messages with "[label] " (e.g. "[PRISM]").
    `naming_hint`, if given, is quoted in the naming-convention error
    message (e.g. "prism_county_daily_<year>_<run_timestamp>.csv").
    """
    prefix = f"[{label}] " if label else ""
    years_to_files: dict[str, list[Path]] = {}
    unparsed = []

    for path in paths:
        match = filename_year_re.match(path.name)
        if not match:
            unparsed.append(path)
            continue
        years_to_files.setdefault(match.group(1), []).append(path)

    if unparsed:
        hint = f"'{naming_hint}' " if naming_hint else ""
        raise ValueError(
            f"{prefix}The following file(s) don't match the expected {hint}"
            f"naming convention -- check before proceeding: {[p.name for p in unparsed]}"
        )

    conflicts = {year: fs for year, fs in years_to_files.items() if len(fs) > 1}
    if conflicts:
        lines = "\n".join(
            f"  {year}: {[p.name for p in fs]}" for year, fs in sorted(conflicts.items())
        )
        raise ValueError(
            f"{prefix}Multiple input files claim the same year -- resolve which "
            f"to keep before aggregating:\n{lines}"
        )

    found_years = {int(y) for y in years_to_files}
    missing = sorted(expected_years - found_years)
    unexpected = sorted(found_years - expected_years)
    if missing:
        print(f"{prefix}Note: {len(missing)} expected year(s) not found among input files: {missing}")
    if unexpected:
        print(
            f"{prefix}Note: {len(unexpected)} input year(s) outside the expected "
            f"{min(expected_years)}-{max(expected_years)} range: {unexpected}"
        )


# ---------------------------------------------------------------------
# Load one year/file, resolving the known WI-county duplicate rows
# (see SCRIPT_OVERVIEW.md).
# ---------------------------------------------------------------------

def resolve_duplicate_rows(daily, duplicate_mask, path):
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

    n_pairs_affected = dup_rows[["geoid", "date"]].drop_duplicates().shape[0]
    n_rows_dropped = int(duplicate_mask.sum()) - n_pairs_affected
    affected_geoids = sorted(dup_rows["geoid"].unique())
    print(
        f"  Note: {path.name} had {n_rows_dropped} exact-duplicate row(s) "
        f"across {n_pairs_affected} geoid/date combination(s) -- confirmed "
        f"byte-identical, dropped automatically. Affected geoid(s): {affected_geoids}"
    )

    return daily.drop_duplicates(subset=["geoid", "date"], keep="first")


def load_daily_extract(path):
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


# ---------------------------------------------------------------------
# Completeness check: flag county-months whose day count doesn't match
# the calendar, rather than silently aggregating a partial month.
# ---------------------------------------------------------------------

def flag_incomplete_months(monthly):
    """Add an `is_incomplete` column: day count vs. expected calendar days."""
    monthly = monthly.copy()

    monthly["expected_days"] = pd.PeriodIndex.from_fields(
        year=monthly["year"].astype(int), month=monthly["month"].astype(int), freq="M"
    ).days_in_month
    monthly["is_incomplete"] = monthly["n_days"] != monthly["expected_days"]
    return monthly
