"""
Aggregates the daily county-level PRISM and ERA5-Land CSVs into
county-year-month panels for both datasets: precipitation (and ERA5's
snowfall) summed to monthly totals, everything else averaged.

- PRISM county-months mixing the AN81/AN91 vintages (2020/2021 boundary)
  are flagged, not silently averaged over; ERA5 has no such vintage
  boundary.
- Same QA checks for both datasets, via aggregation_utils.py: flags
  county-months whose day count doesn't match the calendar, and handles
  duplicate rows (drop-if-identical / error-if-any-non-key-column-disagrees).
"""

import re
from dataclasses import dataclass
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
# Configuration shared across both datasets
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

# Column names produced by 02a_extract_prism_county.py / 04a_extract_era5_county.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Expected extraction years, per 02a/04a's YEARS config (1981-2025 inclusive
# = 45 years). Used only to report missing/unexpected years -- not to
# filter input files.
EXPECTED_YEARS = set(range(1981, 2026))


@dataclass
class DatasetConfig:
    """Per-dataset parameters to run the same aggregation logic against
    either PRISM's or ERA5's daily extract."""

    name: str
    input_dir_candidates: list
    input_pattern: str
    filename_year_re: re.Pattern
    sum_vars: list  # summed to a monthly total (e.g. precipitation)
    mean_vars: list  # averaged to a monthly mean
    output_dir: Path
    output_filename: str
    flagged_filename: str
    has_dataset_type: bool = False  # PRISM-only AN81/AN91 vintage flag


PRISM_CONFIG = DatasetConfig(
    name="PRISM",
    input_dir_candidates=[
        "/mnt/data_f/AnimalCollisionsWeatherData/PRISM/extracted/county_daily_year",  # Kodama server
        REPO_ROOT / "dataRAW" / "PRISM",  # personal dev repo fallback
    ],
    input_pattern="prism_county_daily_*.csv",
    filename_year_re=re.compile(r"^prism_county_daily_(\d{4})_"),
    # Matches PRISM's own documented convention (PRISM notes monthly grids
    # aren't a pure average of the dailies, since the monthlies use more
    # stations than the dailies).
    sum_vars=["ppt"],
    mean_vars=["tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"],
    output_dir=REPO_ROOT / "dataCSV" / "PRISM",
    output_filename="prism_county_month.csv",
    flagged_filename="prism_county_month_incomplete_flagged.csv",
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
    # snow_depth is a stock (snow currently on the ground), not a flux, so
    # it's averaged like the temperature/pressure variables, not summed.
    sum_vars=["precip_mm", "snowfall_mm"],
    mean_vars=[
        "tmean_c",
        "tmin_c",
        "tmax_c",
        "dewpoint_c",
        "skin_temp_c",
        "wind_speed_10m",
        "snow_depth",
        "surface_pressure",
    ],
    output_dir=REPO_ROOT / "dataCSV" / "ERA5",
    output_filename="era5_county_month.csv",
    flagged_filename="era5_county_month_incomplete_flagged.csv",
    has_dataset_type=False,
)

# ---------------------------------------------------------------------
# Aggregate one file's daily county rows to county-year-month
# ---------------------------------------------------------------------

def aggregate_file_to_month(daily: pd.DataFrame, config: DatasetConfig) -> pd.DataFrame:
    """Collapse one file's daily county rows to county-year-month."""
    daily = daily.copy()
    daily["month"] = daily["date"].dt.month

    group_cols = ID_COLS + ["year", "month"]

    agg_kwargs = {"n_days": ("date", "count")}
    agg_kwargs.update({f"{v}_total": (v, "sum") for v in config.sum_vars})
    agg_kwargs.update({f"{v}_mean": (v, "mean") for v in config.mean_vars})

    monthly = daily.groupby(group_cols, as_index=False).agg(**agg_kwargs)

    if config.has_dataset_type:
        # Flag months that mix PRISM vintages (e.g. Dec 2020, which
        # straddles the AN81 -> AN91 switch) so they can be
        # spot-checked/documented rather than silently averaged over
        # without anyone noticing.
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
        monthly_frames.append(aggregate_file_to_month(daily, config))
        del daily  # free the daily rows before loading the next year/file

    monthly = pd.concat(monthly_frames, ignore_index=True)
    group_cols = ID_COLS + ["year", "month"]
    monthly = monthly.sort_values(group_cols).reset_index(drop=True)

    print(f"Loaded {total_daily_rows:,} daily county-day rows across {len(paths)} file(s).")
    print(f"Aggregated to {len(monthly):,} county-month rows.")

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
            f"that doesn't match the calendar days expected for that month -- "
            f"see {config.flagged_filename}."
        )
    else:
        print("No incomplete county-months found (n_days matches calendar days everywhere).")

    config.output_dir.mkdir(parents=True, exist_ok=True)

    output_path = config.output_dir / config.output_filename
    monthly.to_csv(output_path, index=False)
    print(f"Saved {config.name} aggregated county-month table to:\n  {output_path}")

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
