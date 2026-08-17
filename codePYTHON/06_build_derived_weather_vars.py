"""
Constructs derived weather variables from the raw daily PRISM/ERA5 county extracts,
aggregated to county-year-month.

- Missing daily temp/precip readings are excluded from the relevant
  count/sum/mean (default pandas .agg(sum/mean) logic).
- Same QA checks as the aggregation script (05), via aggregation_utils.py:
    - flags county-months whose day count doesn't match the calendar), &
    - handles duplicates (drop-if-identical / error-if-any-non-key-column-disagrees).
"""

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd

from aggregation_utils import (
    check_for_year_conflicts,
    discover_input_files,
    flag_incomplete_months,
    load_daily_extract,
    resolve_data_root,
)

# ---------------------------------------------------------------------
# Configuration shared across both datasets
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

# Column names produced by 02a_extract_prism_county.py / 04a_extract_era5_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Expected extraction years, per 02a/04a's YEARS config (1981-2025 inclusive
# = 45 years). Used only to report missing/unexpected years -- not to
# filter input files.
EXPECTED_YEARS = set(range(1981, 2026))

# Temperature threshold (0F) in Celsius, for metabolic stress in deer:
EXTREME_COLD = (0.0 - 32) * 5 / 9

# Precipitation-above-threshold cutoff. Task doc gives 10mm as example.
PRECIP_THRESHOLD_MM = 10.0

# Heating/cooling degree day
# base temperature: 65F (standard US convention, from NOAA/utility degree-day reporting),
# converted to Celsius to match both datasets' native units.
HDD_CDD_BASE_F = 65.0
HDD_CDD_BASE_C = (HDD_CDD_BASE_F - 32) * 5 / 9


@dataclass
class DatasetConfig:
    """Per-dataset parameters to run the same derivation logic
    against either PRISM's or ERA5's daily extract."""

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
    output_filename="prism_derived_weather_vars.csv", # should contain 1678320 non-header rows (45 years * 3108 counties * 12 months)
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
    output_filename="era5_derived_weather_vars.csv", # should contain 1678320 non-header rows (45 years * 3108 counties * 12 months)
    flagged_filename="era5_derived_weather_vars_incomplete_flagged.csv",
    has_snow=True,
    snowfall_col="snowfall_mm",
    snow_depth_col="snow_depth",
)

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
    # matches 05's missing-data convention (also applied independently
    # by 07d to NOAA station data).
    daily["_extremely_cold"] = daily[config.tmin_col] < EXTREME_COLD
    daily["_freeze_thaw"] = (daily[config.tmin_col] < 0.0) & (daily[config.tmax_col] > 0.0)
    daily["_precip_above_threshold"] = daily[config.precip_col] > PRECIP_THRESHOLD_MM
    daily["_hdd"] = (HDD_CDD_BASE_C - daily[config.tmean_col]).clip(lower=0)
    daily["_cdd"] = (daily[config.tmean_col] - HDD_CDD_BASE_C).clip(lower=0)

    group_cols = ID_COLS + ["year", "month"]

    precip_col_name = f"days_precip_above_{int(PRECIP_THRESHOLD_MM)}mm"
    agg_kwargs = {
        "n_days": ("date", "count"),
        "days_extremely_cold": ("_extremely_cold", "sum"),
        "freeze_thaw_days": ("_freeze_thaw", "sum"),
        precip_col_name: ("_precip_above_threshold", "sum"),
        "heating_degree_days": ("_hdd", "sum"),
        "cooling_degree_days": ("_cdd", "sum"),
        "mean_temp_c": (config.tmean_col, "mean"),
        "tmean_variance_c2": (config.tmean_col, "var"), # sample variance (ddof=1, pandas default)
        "tmin_variance_c2": (config.tmin_col, "var"),
        "tmax_variance_c2": (config.tmax_col, "var"),
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
# Per-dataset pipeline
# ---------------------------------------------------------------------

def process_dataset(config: DatasetConfig) -> pd.DataFrame:
    print(f"\n=== {config.name} ===")

    input_dir = resolve_data_root(config.input_dir_candidates)
    print(f"Reading daily extracts from: {input_dir}")

    paths = discover_input_files(input_dir, config.input_pattern)
    print(f"Found {len(paths)} daily extract file(s).")
    check_for_year_conflicts(paths, config.filename_year_re, EXPECTED_YEARS, label=config.name)

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


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    for config in (PRISM_CONFIG, ERA5_CONFIG):
        process_dataset(config)

if __name__ == "__main__":
    main()
