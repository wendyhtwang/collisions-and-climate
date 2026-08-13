"""
Builds the three-way ground-truth decomposition for ERA5, joining real
NOAA station readings, the independently-extracted "ERA5-at-point" values
(07f), and the production ERA5 county-month panel (07g) -- the ERA5
counterpart to the (manually-built) PRISM ground_truth_spotcheck_summary.xlsx.

- Same two-step decomposition as the PRISM version (station vs.
  ERA5-at-point isolates ERA5-Land's own model behavior; ERA5-at-point vs.
  production county-mean isolates our own extraction/aggregation code) --
  but step (a)'s interpretation differs: ERA5-Land doesn't directly
  assimilate station observations, so that gap reflects model/
  representativeness error, not a station-interpolation algorithm's
  behavior the way PRISM's does. A bigger gap here isn't itself a red flag.
- Reuses 07d_aggregate_noaa_station_daily.py's NOAA station-month values
  as-is (dataset-agnostic, real station data); searches a short list of
  candidate paths for that file since it may only exist wherever 07d was
  actually run, not on every dev copy of this repo.
- No fixed pass/fail tolerance, matching the PRISM methodology: leaves a
  blank `notes` column for the same kind of human interpretation the
  PRISM summary used, rather than trying to automate that judgment call.
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

# First existing candidate wins, same cross-machine-path pattern used
# elsewhere in this repo. Produced by 07d_aggregate_noaa_station_daily.py,
# which writes to a REPO_ROOT-relative path -- so unlike 05/05b's
# INPUT_DIR_CANDIDATES (an external raw-data mount), what's missing here
# isn't a shared mount but simply having run 07d on *this* machine's
# checkout. If 07d was only run elsewhere (e.g. Kodama's shared project
# checkout), add that machine's absolute path too.
NOAA_STATION_MONTH_CANDIDATES = [
    REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "noaa_station_daily_data" / "noaa_station_month.csv",
    Path("/Users/wendyhtw/Documents/CAPP ('25-'27)/Q4 - Summer'26/EPIC/Repos/collisions-and-climate")
    / "dataCSV" / "PRISM" / "spot_check" / "noaa_station_daily_data" / "noaa_station_month.csv",  # local repo fallback
]

ERA5_AT_POINT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_at_point_month.csv"
ERA5_SAMPLE_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_ground_truth_sample.csv"
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_ground_truth_comparison.csv"

# (07f/at-point column, station column, production column, output label).
# At-point columns are bare names (precip_mm); production columns are
# suffixed by aggregation type (_total/_mean) -- keep in sync with 07f's
# SUM_VARS/MEAN_VARS and 05b's actual output columns if either changes.
VARIABLES = [
    ("precip_mm", "ppt_total", "precip_mm_total", "precip_mm"),
    ("tmax_c", "tmax_mean", "tmax_c_mean", "tmax_c"),
    ("tmin_c", "tmin_mean", "tmin_c_mean", "tmin_c"),
    ("tmean_c", "tmean_mean", "tmean_c_mean", "tmean_c"),
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
            "production_n_days": prod_row.get("n_days", None),
            "production_expected_days": prod_row.get("expected_days", None),
            "production_is_incomplete": prod_row.get("is_incomplete", None),
        }

        for point_col, station_col, production_col, label in VARIABLES:
            station_val = station_row[station_col]
            point_val = point_row[point_col]
            county_val = prod_row[production_col]

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
