"""
Aggregate NOAA GHCN-Daily station CSVs (pulled from NCEI's Access Data
Service -- dataset=daily-summaries, see 06c's docstring / the 08.07.26 Fri
team meeting ground-truth station-check plan) to station-year-month, for
direct comparison against dataCSV/PRISM/prism_county_month.csv and
PRISM's single-location Data Explorer values.

Does NO Earth Engine calls, and doesn't import anything from this repo's
PRISM extraction/aggregation scripts -- this is real station data, not a
re-derivation of PRISM, so there's no "independence" concern to preserve
here the way there was for 06_gpt/06b_gpt.

INPUT: any number of per-station daily CSVs directly under
NOAA_STATION_DIR (matching the header row NCEI's API returns, e.g.
STATION, DATE, PRCP, TMAX, TMIN in metric units, per this repo's
`units=metric` request URLs). Filenames are NOT trusted for station/year/
month -- those are derived from the STATION/DATE columns themselves, so
this works regardless of how many months one file covers or how it's
named. Each file must contain exactly one station (raises otherwise).

AGGREGATION: matches production's convention
(04_aggregate_daily_to_monthly.py) -- ppt is a monthly total (sum), tmax/
tmin are monthly means. tmean is derived the same way PRISM itself
derives it ("Tmean ... calculated as (tmax+tmin)/2", per PRISM's own
dataset documentation), computed per day from TMAX/TMIN before averaging,
not averaged from the monthly tmax_mean/tmin_mean after the fact (those
happen to be equal for a plain mean, but computing it the daily way
keeps this consistent with how missing days are handled below).

MISSING DATA: a blank daily reading (e.g. a day with no TMIN, which does
occur -- see USC00123777_2021_12.csv, 2021-12-20) is excluded from that
variable's sum/mean, NOT treated as zero. Zero-filling a missing PRCP day
would silently bias ppt_total low. Each variable's missing-day count is
reported in its own `<var>_n_missing` column rather than silently
dropped, so a month with lots of missing data is visible before treating
its aggregate as reliable.

OUTPUT: one row per station-year-month, written to
NOAA_STATION_DIR/noaa_station_month.csv
"""

import calendar
from pathlib import Path

import pandas as pd

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

    # Daily mean temp, derived the same way PRISM derives its own tmean --
    # (TMAX+TMIN)/2 -- computed BEFORE aggregating, so a day missing either
    # extreme correctly drops out of the month's tmean average too (pandas
    # arithmetic propagates NaN automatically: TMAX + NaN = NaN).
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


def flag_incomplete_months(monthly: pd.DataFrame) -> pd.DataFrame:
    """Same completeness check as 04_aggregate_daily_to_monthly.py: n_days vs calendar days."""
    monthly = monthly.copy()
    monthly["expected_days"] = monthly.apply(
        lambda row: calendar.monthrange(int(row["year"]), int(row["month"]))[1], axis=1
    )
    monthly["is_incomplete"] = monthly["n_days"] != monthly["expected_days"]
    return monthly


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
