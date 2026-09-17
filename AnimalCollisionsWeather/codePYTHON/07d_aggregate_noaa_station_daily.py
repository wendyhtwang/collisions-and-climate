"""
Aggregates downloaded NOAA station daily CSVs to station-year-month, in
the same style as the production PRISM aggregation, so they can be
compared to PRISM's county-month values.

- Derives station/year/month from the DATE column itself rather than
  trusting filenames, so input files can cover any date range. Each file
  must contain exactly one station.
- Matches production's aggregation convention
  (05_aggregate_daily_to_monthly.py): ppt is a monthly total, temperature
  variables are monthly means; tmean is computed per day as
  (tmax+tmin)/2 before averaging, matching PRISM's own documented method.
- A missing daily reading is excluded from that variable's sum/mean (not
  treated as zero), and each variable's missing-day count is reported in
  its own column rather than silently dropped.
- Flags station-months whose day count doesn't match the calendar, same
  completeness check as production (imported from aggregation_utils.py,
  not reimplemented here).
- No Earth Engine calls, no dependency on this repo's PRISM scripts --
  this is real station data, not a re-derivation of PRISM.
"""

from pathlib import Path

import pandas as pd

from aggregation_utils import flag_incomplete_months

REPO_ROOT = Path(__file__).resolve().parents[1]
NOAA_STATION_DIR = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "noaa_station_daily_data"
OUTPUT_PATH = NOAA_STATION_DIR / "noaa_station_month.csv"

INPUT_PATTERN = "*.csv"

# raw NCEI column -> output column. tmean is handled separately since it's
# derived (TMAX+TMIN)/2 per day, not a raw column from the CSV.
SUM_COLS = {"PRCP": "ppt_total"}
MEAN_COLS = {"TMAX": "tmax_mean", "TMIN": "tmin_mean"}


# ---------------------------------------------------------------------
# Load one station file
# ---------------------------------------------------------------------

def load_station_file(path: Path) -> pd.DataFrame:
    """Read one station CSV, derive year/month from DATE, and verify it's single-station."""
    df = pd.read_csv(path, dtype={"STATION": str})
    df["DATE"] = pd.to_datetime(df["DATE"])
    df["year"] = df["DATE"].dt.year
    df["month"] = df["DATE"].dt.month

    stations_present = df["STATION"].unique()
    if len(stations_present) != 1:
        raise ValueError(
            f"{path.name}: expected exactly 1 station, found "
            f"{len(stations_present)}: {sorted(stations_present)}"
        )

    # Daily mean, same method PRISM uses: (TMAX+TMIN)/2, computed before
    # aggregating (NaN propagates, so a missing extreme drops the day).
    df["TMEAN"] = (df["TMAX"] + df["TMIN"]) / 2

    return df


# ---------------------------------------------------------------------
# Aggregate one station's daily rows to station-month
# ---------------------------------------------------------------------

def aggregate_station_month(df: pd.DataFrame) -> pd.DataFrame:
    group_cols = ["STATION", "year", "month"]

    agg_kwargs = {"n_days": ("DATE", "count")}
    for raw_col, out_col in SUM_COLS.items():
        agg_kwargs[out_col] = (raw_col, "sum")
        agg_kwargs[f"{out_col}_n_missing"] = (raw_col, lambda s: s.isna().sum())
    for raw_col, out_col in {**MEAN_COLS, "TMEAN": "tmean_mean"}.items():
        agg_kwargs[out_col] = (raw_col, "mean")
        agg_kwargs[f"{out_col}_n_missing"] = (raw_col, lambda s: s.isna().sum())

    monthly = df.groupby(group_cols, as_index=False).agg(**agg_kwargs)
    return monthly.rename(columns={"STATION": "station_id"})


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def discover_input_files() -> list[Path]:
    paths = sorted(NOAA_STATION_DIR.glob(INPUT_PATTERN))
    paths = [p for p in paths if p.resolve() != OUTPUT_PATH.resolve()]  # skip our own output on a rerun
    if not paths:
        raise FileNotFoundError(f"No CSV files found in {NOAA_STATION_DIR}")
    return paths


def main() -> None:
    paths = discover_input_files()
    print(f"Found {len(paths)} station daily file(s) in {NOAA_STATION_DIR}")

    monthly_frames = []
    for path in paths:
        print(f"  {path.name}")
        daily = load_station_file(path)
        monthly_frames.append(aggregate_station_month(daily))

    monthly = pd.concat(monthly_frames, ignore_index=True)
    monthly = flag_incomplete_months(monthly)

    dup_mask = monthly.duplicated(subset=["station_id", "year", "month"], keep=False)
    if dup_mask.any():
        print(
            "\nWarning: more than one input file produced the same "
            "station-year-month -- check for overlapping/duplicate "
            "downloads:\n"
            f"{monthly.loc[dup_mask, ['station_id', 'year', 'month']].drop_duplicates().to_string(index=False)}"
        )

    monthly = monthly.sort_values(["station_id", "year", "month"]).reset_index(drop=True)

    monthly.to_csv(OUTPUT_PATH, index=False)
    print(f"\nAggregated {len(monthly):,} station-month row(s) from {len(paths)} file(s).")
    print(f"Saved to: {OUTPUT_PATH}")

    incomplete = monthly[monthly["is_incomplete"]]
    if not incomplete.empty:
        print(f"\nNote: {len(incomplete)} station-month row(s) have n_days != calendar days:")
        print(
            incomplete[["station_id", "year", "month", "n_days", "expected_days"]]
            .to_string(index=False)
        )

    missing_cols = [c for c in monthly.columns if c.endswith("_n_missing")]
    rows_with_missing = monthly[monthly[missing_cols].sum(axis=1) > 0]
    if not rows_with_missing.empty:
        print(
            f"\nNote: {len(rows_with_missing)} station-month row(s) have at least one "
            "missing daily reading (excluded from sums/means, not zero-filled):"
        )
        print(
            rows_with_missing[["station_id", "year", "month"] + missing_cols]
            .to_string(index=False)
        )


if __name__ == "__main__":
    main()
