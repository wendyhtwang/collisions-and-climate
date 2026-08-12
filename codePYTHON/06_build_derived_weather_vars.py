"""
Constructs derived weather variables (freeze-thaw days, degree days, etc.)
from the raw daily PRISM/ERA5 county extracts, aggregated to
county-year-month -- per Phase 3 of the task doc. Runs both datasets from
one script (PRISM and ERA5 share the exact same derivation logic, just
different column names/units), unlike 05/05b which are two separate
scripts because their monthly-aggregation column sets differ more.

- Reads the same raw daily extracts as 05/05b (dataRAW/PRISM,
  dataRAW/ERA5, or the Kodama county_daily_year folders) -- NOT 05/05b's
  own monthly output -- so this script is self-contained and its
  `mean_temp_c` can be cross-checked against 05/05b's tmean_mean/
  tmean_c_mean as an independent consistency check.
- Freeze-thaw days is defined explicitly in the task doc: daily min < 0C
  AND daily max > 0C. "Days below freezing" is NOT defined as precisely
  in the task doc -- this script uses the standard climatological
  "frost day" definition (daily min < 0C). FLAGGED assumption -- confirm
  with the team before this is treated as final.
- Heating/cooling degree days use a 65F (18.33C) base temperature, the
  standard US convention. The task doc doesn't specify a base. FLAGGED
  assumption -- confirm with the team, and see the task doc's "optional
  side quest" about species-specific thresholds (deer/elk/turkey/moose),
  which is NOT implemented here (needs a literature review, not a coding
  decision).
- Temperature variance is computed on daily mean temp (tmean/tmean_c) as
  sample variance (ddof=1, pandas default); undefined (NaN) for any
  county-month with only one day of data.
- Precipitation-above-threshold uses the task doc's example threshold
  (10mm) as a configurable constant. Both datasets' precip columns are
  already in mm, so no unit conversion is needed for this comparison.
- Snowfall total and snow depth are ERA5-only (PRISM has no snowfall
  band). Snowfall is summed (a flux); snow depth is averaged (a stock),
  matching 05b's same reasoning for snow_depth. Snow depth stays in
  ERA5-Land's native unit (meters) -- not converted, matching 04/05b.
- Missing daily temp/precip readings are excluded from the relevant
  count/sum/mean, not treated as zero or as "not below freezing" --
  matches 07d's project-wide missing-data convention.
- Same completeness check as 05/05b (flags county-months whose day count
  doesn't match the calendar) and the same automatic-drop-if-identical /
  error-if-conflicting handling of the WI-county duplicate rows (see
  SCRIPT_OVERVIEW.md).
- Reads one year/file at a time per dataset, same memory-management
  reasoning as 05/05b.
- Writes a combined variable-documentation CSV (name, label, unit,
  source, notes) alongside the two derived-var tables, for handoff to
  Charvi's data dictionary -- per the task doc's instruction not to leave
  this only in code comments.
"""

import calendar
import glob
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd

# ---------------------------------------------------------------------
# Configuration shared across both datasets
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

# Column names produced by 02_extract_prism_county.py / 04_extract_era5_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Expected extraction years, per 02/04's YEARS config (1981-2025 inclusive
# = 45 years). Used only to report missing/unexpected years -- not to
# filter input files.
EXPECTED_YEARS = set(range(1981, 2026))

# "Below freezing" = daily TMIN < this value. FLAGGED assumption -- see
# module docstring.
FREEZING_C = 0.0

# Precipitation-above-threshold cutoff. FLAGGED assumption -- task doc
# gives this only as an example value ("e.g., 10mm").
PRECIP_THRESHOLD_MM = 10.0

# Heating/cooling degree day base temperature: 65F, the standard US
# convention (e.g. NOAA/utility degree-day reporting), converted to
# Celsius to match both datasets' native units. FLAGGED assumption -- the
# task doc doesn't specify a base.
HDD_CDD_BASE_F = 65.0
HDD_CDD_BASE_C = (HDD_CDD_BASE_F - 32) * 5 / 9


@dataclass
class DatasetConfig:
    """Per-dataset configuration -- everything 06 needs to know to run the
    same derivation logic against either PRISM's or ERA5's daily extract."""

    name: str
    input_dir_candidates: list
    input_pattern: str
    filename_year_re: re.Pattern
    tmin_col: str
    tmax_col: str
    tmean_col: str
    precip_col: str
    output_dir: Path
    output_filename: str
    flagged_filename: str
    has_dataset_type: bool = False  # PRISM-only AN81/AN91 vintage flag
    has_snow: bool = False  # ERA5-only
    snowfall_col: Optional[str] = None
    snow_depth_col: Optional[str] = None


PRISM_CONFIG = DatasetConfig(
    name="PRISM",
    input_dir_candidates=[
        "/mnt/data_f/AnimalCollisionsWeatherData/PRISM/extracted/county_daily_year",  # Kodama server
        REPO_ROOT / "dataRAW" / "PRISM",  # personal dev repo fallback
    ],
    input_pattern="prism_county_daily_*.csv",
    filename_year_re=re.compile(r"^prism_county_daily_(\d{4})_"),
    tmin_col="tmin",
    tmax_col="tmax",
    tmean_col="tmean",
    precip_col="ppt",
    output_dir=REPO_ROOT / "dataCSV" / "PRISM",
    output_filename="prism_derived_weather_vars.csv",
    flagged_filename="prism_derived_weather_vars_incomplete_flagged.csv",
    has_dataset_type=True,
)

ERA5_CONFIG = DatasetConfig(
    name="ERA5",
    input_dir_candidates=[
        "/mnt/data_f/AnimalCollisionsWeatherData/ERA5/extracted/county_daily_year",  # Kodama server
        REPO_ROOT / "dataRAW" / "ERA5",  # personal dev repo fallback
    ],
    input_pattern="era5_county_daily_*.csv",
    filename_year_re=re.compile(r"^era5_county_daily_(\d{4})_"),
    tmin_col="tmin_c",
    tmax_col="tmax_c",
    tmean_col="tmean_c",
    precip_col="precip_mm",
    output_dir=REPO_ROOT / "dataCSV" / "ERA5",
    output_filename="era5_derived_weather_vars.csv",
    flagged_filename="era5_derived_weather_vars_incomplete_flagged.csv",
    has_snow=True,
    snowfall_col="snowfall_mm",
    snow_depth_col="snow_depth",
)

# Data dictionary for the derived variables themselves, independent of
# dataset -- printed/written once, not duplicated per dataset. Handed off
# for Charvi to fold into the main data dictionary (per task doc).
DERIVED_VAR_DOCS = [
    dict(
        variable="days_below_freezing",
        label="Number of days in the county-month where daily min temp was below freezing",
        unit="days",
        source="PRISM tmin / ERA5-Land tmin_c",
        notes=(
            f"Threshold: daily TMIN < {FREEZING_C}C (standard climatological "
            "'frost day' definition). ASSUMPTION -- task doc doesn't specify "
            "min/max/mean; confirm with team. Missing daily readings are "
            "excluded, not counted as below-freezing."
        ),
    ),
    dict(
        variable="freeze_thaw_days",
        label="Number of days in the county-month where daily min temp < 0C AND daily max temp > 0C",
        unit="days",
        source="PRISM tmin/tmax / ERA5-Land tmin_c/tmax_c",
        notes="Definition given explicitly in the task doc.",
    ),
    dict(
        variable="mean_temp_c",
        label="Mean of daily mean temperature over the county-month",
        unit="degrees C",
        source="PRISM tmean / ERA5-Land tmean_c",
        notes=(
            "Recomputed here directly from the daily extract (not read "
            "from 05/05b's output) so 06 is self-contained; should match "
            "05/05b's tmean_mean/tmean_c_mean and can be used as a "
            "cross-check between the two scripts."
        ),
    ),
    dict(
        variable="tmean_variance_c2",
        label="Sample variance (ddof=1) of daily mean temperature within the county-month",
        unit="degrees C squared",
        source="PRISM tmean / ERA5-Land tmean_c",
        notes=(
            "ASSUMPTION -- task doc says 'temperature variance' without "
            "specifying which series; uses daily mean temp. NaN for any "
            "county-month with only 1 day of data (variance undefined)."
        ),
    ),
    dict(
        variable=f"days_precip_gt_{int(PRECIP_THRESHOLD_MM)}mm",
        label=f"Number of days in the county-month with precipitation above {PRECIP_THRESHOLD_MM}mm",
        unit="days",
        source="PRISM ppt / ERA5-Land precip_mm",
        notes=(
            f"Threshold ({PRECIP_THRESHOLD_MM}mm) is the task doc's example "
            "value, set via PRECIP_THRESHOLD_MM. Both datasets' precip "
            "columns are already in mm."
        ),
    ),
    dict(
        variable="heating_degree_days",
        label="Sum over the county-month of max(base_temp - daily_mean_temp, 0)",
        unit="degree-C-days",
        source="PRISM tmean / ERA5-Land tmean_c",
        notes=(
            f"Base temperature {HDD_CDD_BASE_F}F ({HDD_CDD_BASE_C:.2f}C), the "
            "standard US degree-day convention. ASSUMPTION -- task doc "
            "doesn't specify a base; confirm with team. Species-specific "
            "thresholds (task doc's 'optional side quest') are not "
            "implemented -- would need a literature review, not a coding "
            "decision."
        ),
    ),
    dict(
        variable="cooling_degree_days",
        label="Sum over the county-month of max(daily_mean_temp - base_temp, 0)",
        unit="degree-C-days",
        source="PRISM tmean / ERA5-Land tmean_c",
        notes=f"Same base temperature and assumption as heating_degree_days.",
    ),
    dict(
        variable="total_snowfall_mm",
        label="Total snowfall over the county-month",
        unit="mm",
        source="ERA5-Land snowfall_mm",
        notes="ERA5-only -- PRISM has no snowfall band. Summed (a flux).",
    ),
    dict(
        variable="mean_snow_depth",
        label="Mean snow depth over the county-month",
        unit="meters (ERA5-Land native unit, not converted)",
        source="ERA5-Land snow_depth",
        notes=(
            "ERA5-only -- PRISM has no snow depth band. Averaged, not "
            "summed: snow depth is a stock (snow currently on the "
            "ground), not a flux -- same reasoning as 05b's snow_depth_mean."
        ),
    ),
    dict(
        variable="dataset_types",
        label="PRISM dataset vintage(s) (AN81/AN91) contributing to this county-month",
        unit="n/a (categorical)",
        source="PRISM dataset_type",
        notes=(
            "PRISM-only. Flags (comma-joined) county-months that mix "
            "vintages, which happens at the 2020/2021 boundary -- same "
            "flag as 05."
        ),
    ),
]


# ---------------------------------------------------------------------
# Paths / file discovery (mirrors 05/05b)
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
        "the dataset's input_dir_candidates."
    )


def discover_input_files(input_dir: Path, pattern: str) -> list[Path]:
    """Return sorted paths to daily extract files matching `pattern`."""
    paths = sorted(Path(p) for p in glob.glob(str(input_dir / pattern)))

    if not paths:
        raise FileNotFoundError(f"No files matching '{pattern}' found in {input_dir}")

    return paths


def check_for_year_conflicts(paths: list[Path], config: DatasetConfig) -> None:
    """
    Raise if any file doesn't match the expected <year> naming convention
    (e.g. a small-scale test file sitting in the same folder), or if more
    than one input file claims the same year -- stops rather than silently
    guessing which file to use. Same check as 05/05b.
    """
    years_to_files: dict[str, list[Path]] = {}
    unparsed = []

    for path in paths:
        match = config.filename_year_re.match(path.name)
        if not match:
            unparsed.append(path)
            continue
        years_to_files.setdefault(match.group(1), []).append(path)

    if unparsed:
        raise ValueError(
            f"[{config.name}] The following file(s) don't match the "
            f"expected naming convention -- check before proceeding: "
            f"{[p.name for p in unparsed]}"
        )

    conflicts = {year: fs for year, fs in years_to_files.items() if len(fs) > 1}
    if conflicts:
        lines = "\n".join(
            f"  {year}: {[p.name for p in fs]}" for year, fs in sorted(conflicts.items())
        )
        raise ValueError(
            f"[{config.name}] Multiple input files claim the same year -- "
            f"resolve which to keep before aggregating:\n{lines}"
        )

    found_years = {int(y) for y in years_to_files}
    missing = sorted(EXPECTED_YEARS - found_years)
    unexpected = sorted(found_years - EXPECTED_YEARS)
    if missing:
        print(f"  [{config.name}] Note: {len(missing)} expected year(s) not found among input files: {missing}")
    if unexpected:
        print(f"  [{config.name}] Note: {len(unexpected)} input year(s) outside 1981-2025: {unexpected}")


# ---------------------------------------------------------------------
# Load one year/file, resolving the known WI-county duplicate rows
# (same known case documented in SCRIPT_OVERVIEW.md for 05/05b).
# ---------------------------------------------------------------------

def resolve_duplicate_rows(daily: pd.DataFrame, duplicate_mask: pd.Series, path: Path) -> pd.DataFrame:
    """Handle geoid/date rows that appear more than once in a single file, w/o hard-erroring."""
    dup_rows = daily[duplicate_mask]

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
    # infers these as integers and silently drops leading zeros.
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
# Derive county-month variables from one year's daily rows
# ---------------------------------------------------------------------

def compute_month_derived_vars(daily: pd.DataFrame, config: DatasetConfig) -> pd.DataFrame:
    """Collapse one file's daily county rows to county-year-month derived vars."""
    daily = daily.copy()
    daily["month"] = daily["date"].dt.month

    # Per-day boolean/numeric helper columns, computed once so the
    # groupby-agg below is fully vectorized. NaN inputs propagate to NaN
    # comparisons (treated as False by pandas boolean ops here), which
    # means a missing daily reading is excluded from these counts rather
    # than counted as "not below freezing" / "not above threshold" --
    # matches 07d's missing-data convention.
    daily["_below_freezing"] = daily[config.tmin_col] < FREEZING_C
    daily["_freeze_thaw"] = (daily[config.tmin_col] < FREEZING_C) & (daily[config.tmax_col] > FREEZING_C)
    daily["_precip_above_threshold"] = daily[config.precip_col] > PRECIP_THRESHOLD_MM
    daily["_hdd"] = (HDD_CDD_BASE_C - daily[config.tmean_col]).clip(lower=0)
    daily["_cdd"] = (daily[config.tmean_col] - HDD_CDD_BASE_C).clip(lower=0)

    group_cols = ID_COLS + ["year", "month"]

    precip_col_name = f"days_precip_gt_{int(PRECIP_THRESHOLD_MM)}mm"
    agg_kwargs = {
        "n_days": ("date", "count"),
        "days_below_freezing": ("_below_freezing", "sum"),
        "freeze_thaw_days": ("_freeze_thaw", "sum"),
        precip_col_name: ("_precip_above_threshold", "sum"),
        "heating_degree_days": ("_hdd", "sum"),
        "cooling_degree_days": ("_cdd", "sum"),
        "mean_temp_c": (config.tmean_col, "mean"),
        "tmean_variance_c2": (config.tmean_col, "var"),
    }
    if config.has_snow:
        agg_kwargs["total_snowfall_mm"] = (config.snowfall_col, "sum")
        agg_kwargs["mean_snow_depth"] = (config.snow_depth_col, "mean")

    monthly = daily.groupby(group_cols, as_index=False).agg(**agg_kwargs)

    if config.has_dataset_type:
        dataset_types = (
            daily.groupby(group_cols)["dataset_type"]
            .agg(lambda values: ",".join(sorted(set(values))))
            .reset_index()
            .rename(columns={"dataset_type": "dataset_types"})
        )
        monthly = monthly.merge(dataset_types, on=group_cols, how="left")

    return monthly


# ---------------------------------------------------------------------
# Completeness check (same as 05/05b): flag county-months whose day count
# doesn't match the calendar, rather than silently treating a partial
# month's derived counts/sums as if they covered the full month.
# ---------------------------------------------------------------------

def flag_incomplete_months(monthly: pd.DataFrame) -> pd.DataFrame:
    """Add an `is_incomplete` column: day count vs. expected calendar days."""
    monthly = monthly.copy()
    expected_days = monthly.apply(
        lambda row: calendar.monthrange(int(row["year"]), int(row["month"]))[1], axis=1
    )
    monthly["expected_days"] = expected_days
    monthly["is_incomplete"] = monthly["n_days"] != monthly["expected_days"]
    return monthly


# ---------------------------------------------------------------------
# Per-dataset pipeline
# ---------------------------------------------------------------------

def process_dataset(config: DatasetConfig) -> pd.DataFrame:
    print(f"\n=== {config.name} ===")

    input_dir = resolve_data_root(config.input_dir_candidates)
    print(f"Reading daily extracts from: {input_dir}")

    paths = discover_input_files(input_dir, config.input_pattern)
    print(f"Found {len(paths)} daily extract file(s).")
    check_for_year_conflicts(paths, config)

    monthly_frames = []
    total_daily_rows = 0

    for i, path in enumerate(paths, start=1):
        print(f"  [{i}/{len(paths)}] {path.name}")
        daily = load_daily_extract(path)
        total_daily_rows += len(daily)
        monthly_frames.append(compute_month_derived_vars(daily, config))
        del daily  # free the daily rows before loading the next year/file

    monthly = pd.concat(monthly_frames, ignore_index=True)
    group_cols = ID_COLS + ["year", "month"]
    monthly = monthly.sort_values(group_cols).reset_index(drop=True)

    print(f"Loaded {total_daily_rows:,} daily county-day rows across {len(paths)} file(s).")
    print(f"Derived {len(monthly):,} county-month rows.")

    monthly = flag_incomplete_months(monthly)

    if config.has_dataset_type:
        mixed_vintage = monthly[monthly["dataset_types"].str.contains(",")]
        if not mixed_vintage.empty:
            months = mixed_vintage[["year", "month"]].drop_duplicates()
            print(
                "Note: the following year-month(s) mix PRISM dataset "
                "vintages (AN81/AN91) -- expected at the 2020/2021 boundary:"
            )
            print(months.to_string(index=False))

    incomplete = monthly[monthly["is_incomplete"]]
    if not incomplete.empty:
        print(
            f"Warning: {len(incomplete):,} county-month row(s) have a day count "
            f"that doesn't match the calendar days expected -- see "
            f"{config.flagged_filename}."
        )
    else:
        print("No incomplete county-months found (n_days matches calendar days everywhere).")

    config.output_dir.mkdir(parents=True, exist_ok=True)

    output_path = config.output_dir / config.output_filename
    monthly.to_csv(output_path, index=False)
    print(f"Saved {config.name} derived weather variables to:\n  {output_path}")

    if not incomplete.empty:
        flagged_path = config.output_dir / config.flagged_filename
        incomplete.to_csv(flagged_path, index=False)
        print(f"Saved incomplete-month rows for review to:\n  {flagged_path}")

    return monthly


def write_data_dictionary() -> None:
    """
    Write the derived-variable documentation (name, label, unit, source,
    notes/assumptions) to a standalone CSV, for Charvi to fold into the
    main project data dictionary -- per the task doc's instruction not to
    leave this only in code comments.
    """
    output_path = REPO_ROOT / "dataCSV" / "derived_weather_vars_data_dictionary.csv"
    pd.DataFrame(DERIVED_VAR_DOCS).to_csv(output_path, index=False)
    print(f"\nSaved derived-variable documentation to:\n  {output_path}")


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    for config in (PRISM_CONFIG, ERA5_CONFIG):
        process_dataset(config)

    write_data_dictionary()

    print(
        "\nFlagged assumptions to confirm with the team before treating "
        "these as final (see module docstring / data dictionary 'notes' "
        "column for detail): the below-freezing threshold definition "
        f"(TMIN < {FREEZING_C}C), the precip-above-threshold cutoff "
        f"({PRECIP_THRESHOLD_MM}mm), and the heating/cooling degree-day "
        f"base temperature ({HDD_CDD_BASE_F}F / {HDD_CDD_BASE_C:.2f}C)."
    )


if __name__ == "__main__":
    main()
