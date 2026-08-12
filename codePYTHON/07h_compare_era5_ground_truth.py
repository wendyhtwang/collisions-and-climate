"""
Builds the three-way ground-truth decomposition for ERA5, joining real
NOAA station readings, the independently-extracted "ERA5-at-point" values
(07f), and the production ERA5 county-month panel (07g) -- the ERA5
counterpart to the (manually-built) PRISM ground_truth_spotcheck_summary.xlsx.

- Same decomposition logic as the PRISM version, split into two
  independent steps rather than one station-vs-county-mean comparison
  (which would conflate two different effects):
    (a) station vs. ERA5-at-point -- isolates ERA5-Land's own
        reanalysis/land-surface-model behavior at that point.
    (b) ERA5-at-point vs. production county-mean -- isolates the effect
        of our own extraction/aggregation code (the county-averaging
        step), same as PRISM's decomposition.
  Note the interpretation of step (a) differs from PRISM's: ERA5-Land
  doesn't directly assimilate station observations (see
  https://confluence.ecmwf.int/display/CKB/ERA5-Land:+data+documentation),
  so this gap reflects model/representativeness error, not a station-
  interpolation algorithm's behavior the way PRISM's CAI does. A bigger
  gap here than PRISM's equivalent step isn't itself a red flag.
- Reuses the NOAA station-month values 07d_aggregate_noaa_station_daily.py
  already computed for the PRISM check as-is (dataset-agnostic -- these
  are real station readings, independent of both PRISM and ERA5).
  Searches a short list of candidate paths for that file rather than
  assuming it's on this machine, since it may only exist wherever 07d was
  actually run (e.g. Kodama) and not be synced to every dev copy of this
  repo.
- No fixed pass/fail tolerance, matching the PRISM methodology: leaves a
  blank `notes` column for the same kind of human interpretation the
  PRISM summary used (e.g. tracing a gap to a station's coastal siting),
  rather than trying to automate that judgment call.
"""

from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]

# Keep in sync with 07f_extract_era5_ground_truth_points.py and
# 07g_filter_era5_ground_truth_sample.py.
GROUND_TRUTH_CASES = [
    {"geoid": "18009", "county": "Blackford", "state": "IN", "year": 2021, "month": 12,
     "station_id": "USC00123777"},
    {"geoid": "37041", "county": "Chowan", "state": "NC", "year": 2000, "month": 1,
     "station_id": "USC00312635"},
    {"geoid": "47127", "county": "Moore", "state": "TN", "year": 1999, "month": 6,
     "station_id": "USC00405525"},
]

# First existing candidate wins, same pattern gee_extract_utils.py and
# 05b_aggregate_era5_daily_to_monthly.py already use for cross-machine
# paths. This file is produced by 07d_aggregate_noaa_station_daily.py,
# which may have only ever been run wherever the PRISM ground-truth check
# was done (e.g. Kodama), not on every dev copy of this repo.
NOAA_STATION_MONTH_CANDIDATES = [
    REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "noaa_station_daily_data" / "noaa_station_month.csv",
]

ERA5_AT_POINT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_at_point_month.csv"
ERA5_SAMPLE_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_ground_truth_sample.csv"
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_ground_truth_comparison.csv"

# (era5/production column, station column, output label)
VARIABLES = [
    ("precip_mm", "ppt_total", "precip_mm"),
    ("tmax_c", "tmax_mean", "tmax_c"),
    ("tmin_c", "tmin_mean", "tmin_c"),
    ("tmean_c", "tmean_mean", "tmean_c"),
]


def resolve_noaa_station_month_path() -> Path:
    for path in NOAA_STATION_MONTH_CANDIDATES:
        if path.exists():
            return path
    raise FileNotFoundError(
        "noaa_station_month.csv not found at any candidate path:\n"
        + "\n".join(f"  {p}" for p in NOAA_STATION_MONTH_CANDIDATES)
        + "\n\nThis file is produced by 07d_aggregate_noaa_station_daily.py from the PRISM "
        "ground-truth check and reused as-is here (it's real station data, independent of "
        "both PRISM and ERA5). Sync it from wherever 07d was run, or add this machine's path "
        "to NOAA_STATION_MONTH_CANDIDATES."
    )


def load_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    station_path = resolve_noaa_station_month_path()
    print(f"NOAA station-month (reused from PRISM check): {station_path}")
    station = pd.read_csv(station_path, dtype={"station_id": str})

    if not ERA5_AT_POINT_PATH.exists():
        raise FileNotFoundError(
            f"{ERA5_AT_POINT_PATH} not found -- run 07f_extract_era5_ground_truth_points.py first."
        )
    print(f"ERA5-at-point (07f output): {ERA5_AT_POINT_PATH}")
    at_point = pd.read_csv(ERA5_AT_POINT_PATH, dtype={"geoid": str, "station_id": str})

    if not ERA5_SAMPLE_PATH.exists():
        raise FileNotFoundError(
            f"{ERA5_SAMPLE_PATH} not found -- run 07g_filter_era5_ground_truth_sample.py first."
        )
    print(f"ERA5 production sample (07g output): {ERA5_SAMPLE_PATH}")
    production = pd.read_csv(ERA5_SAMPLE_PATH, dtype={"geoid": str})

    return station, at_point, production


def build_comparison(station: pd.DataFrame, at_point: pd.DataFrame, production: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for case in GROUND_TRUTH_CASES:
        geoid, year, month, station_id = case["geoid"], case["year"], case["month"], case["station_id"]

        station_row = station[
            (station["station_id"] == station_id) & (station["year"] == year) & (station["month"] == month)
        ]
        point_row = at_point[(at_point["geoid"] == geoid) & (at_point["year"] == year) & (at_point["month"] == month)]
        prod_row = production[(production["geoid"] == geoid) & (production["year"] == year) & (production["month"] == month)]

        missing_from = []
        if station_row.empty:
            missing_from.append(f"noaa_station_month.csv (station {station_id}, {year}-{month:02d})")
        if point_row.empty:
            missing_from.append(f"era5_at_point_month.csv (geoid {geoid}, {year}-{month:02d})")
        if prod_row.empty:
            missing_from.append(f"era5_ground_truth_sample.csv (geoid {geoid}, {year}-{month:02d})")
        if missing_from:
            print(f"  Skipping {case['county']} County, {case['state']} -- missing from: {', '.join(missing_from)}")
            continue

        station_row, point_row, prod_row = station_row.iloc[0], point_row.iloc[0], prod_row.iloc[0]

        row = {
            "geoid": geoid, "county": case["county"], "state": case["state"],
            "year": year, "month": month, "station_id": station_id,
            "era5_n_hours_captured": point_row["n_hours_captured"],
            "era5_expected_hours": point_row["expected_hours"],
            "era5_n_days_flagged": point_row["n_days_flagged"],
            "station_is_incomplete": station_row.get("is_incomplete", None),
        }

        for era5_col, station_col, label in VARIABLES:
            station_val = station_row[station_col]
            point_val = point_row[era5_col]
            county_val = prod_row[era5_col]

            row[f"{label}_station"] = station_val
            row[f"{label}_era5_point"] = point_val
            row[f"{label}_era5_county"] = county_val
            row[f"{label}_delta_point_minus_station"] = point_val - station_val
            row[f"{label}_delta_county_minus_point"] = county_val - point_val
            row[f"{label}_delta_county_minus_station_total"] = county_val - station_val
            if station_val:
                row[f"{label}_pct_delta_total"] = (county_val - station_val) / abs(station_val) * 100

        row["notes"] = ""  # fill in by hand, same as ground_truth_spotcheck_summary.xlsx
        rows.append(row)

    return pd.DataFrame(rows)


def main() -> None:
    station, at_point, production = load_inputs()
    comparison = build_comparison(station, at_point, production)

    if comparison.empty:
        raise RuntimeError("No ground-truth cases could be fully matched across all three inputs.")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    comparison.to_csv(OUTPUT_PATH, index=False)

    print(f"\n{len(comparison)} of {len(GROUND_TRUTH_CASES)} ground-truth case(s) compared.")
    print(f"Saved to: {OUTPUT_PATH}")
    print(
        "\nAs with the PRISM version: no fixed pass/fail tolerance here. Open the CSV, read "
        "the two delta steps per variable, and fill in `notes` by hand for anything that "
        "looks like more than an explainable representativeness gap -- a large "
        "delta_county_minus_point (step b) is the one that would actually point at our own "
        "extraction/aggregation code."
    )


if __name__ == "__main__":
    main()
