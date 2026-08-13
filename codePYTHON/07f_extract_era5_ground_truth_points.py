"""
Parses the independently-downloaded ERA5-Land hourly GRIB files (pulled
directly from the Copernicus CDS, not GEE) for the ground-truth stations,
and aggregates each to an "ERA5-at-point" county-year-month value -- the
ERA5 counterpart to PRISM's Data Explorer point lookup.

- Independent of GEE and this repo's own extraction code: these files were
  downloaded straight from the CDS, so a bug shared with the production
  pipeline wouldn't be invisible to this check.
- Uses `cfgrib.open_datasets()` (plural), not `open_dataset()`: ERA5-Land
  hourly downloads bundle variables across incompatible GRIB groups that
  can't be merged into a single dataset.
- Precip/snowfall are ERA5(-Land)'s "accumulated since reference time"
  fields, so each day's total is the last available step of that day's
  own block, not a diff of consecutive hours. The last day of a requested
  month is often missing its final step; that row is flagged
  (`n_days_flagged`) rather than silently under-counted.
- tmin/tmax/tmean and wind speed follow production's exact order of
  operations (04_extract_era5_county.py's `add_derived_bands()`): wind
  speed comes from the daily mean u/v components, not the mean of hourly
  speeds.
- Grid-cell selection falls back to the nearest unmasked cell if the
  closest one is land-sea-masked (see "ERA5-Land land-sea masking" in
  SCRIPT_OVERVIEW.md), flagging the row (`used_fallback_grid_cell`)
  rather than returning all-NaN monthly stats.
- Monthly aggregation convention matches
  05b_aggregate_era5_daily_to_monthly.py exactly: precip_mm/snowfall_mm
  summed, everything else averaged.
"""

from __future__ import annotations

import re
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
import cfgrib

# ---------------------------------------------------------------------
# Ground-truth cases -- keep in sync with 07g_filter_era5_ground_truth_sample.py
# and 07h_compare_era5_ground_truth.py. Coordinates rounded to 1 decimal
# (from the PRISM ground-truth summary) -- within one ERA5-Land grid cell
# (0.1 deg), so nearest-neighbor selection below is robust to it.
# ---------------------------------------------------------------------

GROUND_TRUTH_CASES = [
    {
        "geoid": "18009", "county": "Blackford", "state": "IN",
        "year": 2021, "month": 12,
        "station_id": "USC00123777", "station_lat": 40.4, "station_lon": -85.3,
    },
    {
        "geoid": "37041", "county": "Chowan", "state": "NC",
        "year": 2000, "month": 1,
        "station_id": "USC00312635", "station_lat": 36.0, "station_lon": -76.6,
    },
    {
        "geoid": "47127", "county": "Moore", "state": "TN",
        "year": 1999, "month": 6,
        "station_id": "USC00405525", "station_lat": 35.3, "station_lon": -86.4,
    },
]

REPO_ROOT = Path(__file__).resolve().parents[1]
INPUT_DIR = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "raw_hourly"
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "spot_check" / "era5_at_point_month.csv"

# How far (degrees) the nearest grid point may sit from the station's
# known coordinate before treating it as a mismatch rather than rounding
# noise. ERA5-Land grid spacing is 0.1 deg; 1.5x catches "wrong file" cases.
MAX_POINT_DISTANCE_DEG = 0.15

# When the nearest cell is masked (see "ERA5-Land land-sea masking" in
# SCRIPT_OVERVIEW.md), how far to search for a valid one, and how much
# NaN in a cell's series counts as "masked" vs. expected boundary gaps.
MAX_FALLBACK_DISTANCE_DEG = 0.35
MAX_ACCEPTABLE_NAN_FRACTION = 0.10

SUM_VARS = ["precip_mm", "snowfall_mm"]
MEAN_VARS = [
    "tmean_c", "tmin_c", "tmax_c", "dewpoint_c", "skin_temp_c",
    "wind_speed_10m", "snow_depth", "surface_pressure",
]


# ---------------------------------------------------------------------
# GRIB loading
# ---------------------------------------------------------------------

def load_groups(path: Path) -> list[xr.Dataset]:
    """
    Open all internally-consistent variable groups in one GRIB file, and
    normalize any 0-360 longitude to -180/180 so every group indexes the
    same way.

    `indexpath=""` disables cfgrib's on-disk .idx cache: in a cloud-synced
    folder, a stale/locked .idx file can make cfgrib read garbage instead
    of the real GRIB bytes. Re-parsing each run avoids that at a small
    time cost.
    """
    with warnings.catch_warnings():
        # cfgrib doesn't expose xr.merge's `compat` kwarg, so this can't be
        # fixed by passing something through -- scoped narrowly here so
        # unrelated FutureWarnings elsewhere still surface normally.
        warnings.filterwarnings(
            "ignore", category=FutureWarning,
            message=".*compat.*no_conflicts.*override.*",
        )
        groups = cfgrib.open_datasets(str(path), backend_kwargs={"indexpath": ""})
    normalized = []
    for ds in groups:
        lon = ds.longitude.values
        if lon.max() > 180:
            ds = ds.assign_coords(longitude=(((lon + 180) % 360) - 180))
            ds = ds.sortby("longitude")
        normalized.append(ds)
    return normalized


def find_var(groups: list[xr.Dataset], short_name: str) -> xr.DataArray:
    for ds in groups:
        if short_name in ds.data_vars:
            return ds[short_name]
    raise KeyError(f"Variable '{short_name}' not found in any group of this file.")


# ---------------------------------------------------------------------
# Point selection
# ---------------------------------------------------------------------

def resolve_valid_point(groups: list[xr.Dataset], lat: float, lon: float) -> dict:
    """
    Find the grid cell to use for this station: the nearest one if it has
    real data, otherwise the nearest unmasked cell within
    MAX_FALLBACK_DISTANCE_DEG (see SCRIPT_OVERVIEW.md). Checked against
    `t2m` only -- the land-sea mask is the same for every variable.
    """
    da = find_var(groups, "t2m")
    lats = da.latitude.values
    lons = da.longitude.values

    candidates = []
    for la in lats:
        for lo in lons:
            cell = da.sel(latitude=la, longitude=lo)
            nan_fraction = float(np.isnan(cell.values).mean())
            dist = float(np.hypot(la - lat, lo - lon))
            candidates.append((dist, nan_fraction, float(la), float(lo)))

    candidates.sort(key=lambda c: c[0])  # nearest first
    nearest_dist, nearest_nan_frac, nearest_lat, nearest_lon = candidates[0]

    if nearest_nan_frac <= MAX_ACCEPTABLE_NAN_FRACTION:
        return {
            "lat": nearest_lat, "lon": nearest_lon,
            "used_fallback": False, "fallback_distance_deg": 0.0,
        }

    valid_candidates = [c for c in candidates if c[1] <= MAX_ACCEPTABLE_NAN_FRACTION and c[0] <= MAX_FALLBACK_DISTANCE_DEG]
    if not valid_candidates:
        raise ValueError(
            f"No grid cell within {MAX_FALLBACK_DISTANCE_DEG} deg of ({lat}, {lon}) has usable "
            f"data (nearest cell is {nearest_nan_frac:.0%} NaN -- likely a land-sea-masked "
            "cell, e.g. a coastal/water-adjacent station). Widen MAX_FALLBACK_DISTANCE_DEG or "
            "re-download a larger box for this station."
        )

    valid_candidates.sort(key=lambda c: c[0])
    fallback_dist, fallback_nan_frac, fallback_lat, fallback_lon = valid_candidates[0]
    print(
        f"    NOTE: nearest grid cell ({nearest_lat}, {nearest_lon}) is "
        f"{nearest_nan_frac:.0%} NaN (ERA5-Land land-sea mask -- likely a water-dominated "
        f"cell). Using the nearest valid cell instead: ({fallback_lat}, {fallback_lon}), "
        f"{fallback_dist:.3f} deg from the station."
    )
    return {
        "lat": fallback_lat, "lon": fallback_lon,
        "used_fallback": True, "fallback_distance_deg": fallback_dist,
    }


def select_point(da: xr.DataArray, lat: float, lon: float) -> xr.DataArray:
    point = da.sel(latitude=lat, longitude=lon, method="nearest")
    dist = np.hypot(point.latitude.item() - lat, point.longitude.item() - lon)
    if dist > MAX_POINT_DISTANCE_DEG:
        raise ValueError(
            f"Nearest grid point ({point.latitude.item()}, {point.longitude.item()}) is "
            f"{dist:.3f} deg from the requested station coordinate ({lat}, {lon}) -- further "
            f"than the {MAX_POINT_DISTANCE_DEG} deg sanity threshold. This file's box likely "
            "doesn't actually cover this station; check for a mislabeled/wrong download."
        )
    return point


# ---------------------------------------------------------------------
# Daily aggregation
# ---------------------------------------------------------------------

def daily_accumulated_totals(da: xr.DataArray, year: int, month: int) -> pd.DataFrame:
    """
    Daily total for an accumulated field (precip, snowfall): each day's
    reference-time block accumulates from zero across 24 steps, so the
    total is that block's last available step. Flags days missing
    step=24 (expected for the last day of the range -- see
    SCRIPT_OVERVIEW.md).
    """
    rows = []
    for i, t in enumerate(da.time.values):
        ts = pd.Timestamp(t)
        if not (ts.year == year and ts.month == month):
            continue

        day_values = da.isel(time=i).values  # one value per step
        valid_idx = np.where(~np.isnan(day_values))[0]
        if valid_idx.size == 0:
            rows.append({"date": ts.date(), "total_m": np.nan, "n_steps": 0, "flagged": True})
            continue

        last_idx = valid_idx.max()
        n_steps = last_idx + 1  # steps are 1-indexed hours; array is 0-indexed
        rows.append({
            "date": ts.date(),
            "total_m": day_values[last_idx],
            "n_steps": int(n_steps),
            "flagged": n_steps < 24,
        })

    return pd.DataFrame(rows)


def daily_instant_stats(groups: list[xr.Dataset], short_name: str, lat: float, lon: float,
                         year: int, month: int) -> pd.DataFrame:
    """Daily mean/min/max of an instantaneous field, bucketed by valid_time (not the raw time coord)."""
    da = find_var(groups, short_name)
    point = select_point(da, lat, lon)

    if "step" in point.dims:
        valid_time = point.valid_time.values.flatten()
        values = point.values.flatten()
    else:
        valid_time = point.time.values  # already the valid time (e.g. skin_temperature's group)
        values = point.values

    df = pd.DataFrame({"valid_time": pd.to_datetime(valid_time), "value": values}).dropna()
    df = df[(df.valid_time.dt.year == year) & (df.valid_time.dt.month == month)]
    df["date"] = df.valid_time.dt.date

    daily = df.groupby("date")["value"].agg(["mean", "min", "max", "count"])
    return daily


# ---------------------------------------------------------------------
# One station-month
# ---------------------------------------------------------------------

def process_case(case: dict, path: Path, groups: list[xr.Dataset]) -> dict:
    print(f"  Processing {case['county']} County, {case['state']} "
          f"({case['year']}-{case['month']:02d}) from {path.name}")
    year, month = case["year"], case["month"]

    resolved = resolve_valid_point(groups, case["station_lat"], case["station_lon"])
    lat, lon = resolved["lat"], resolved["lon"]

    # --- accumulated: precip, snowfall ---
    tp_point = select_point(find_var(groups, "tp"), lat, lon)
    sf_point = select_point(find_var(groups, "sf"), lat, lon)
    tp_daily = daily_accumulated_totals(tp_point, year, month)
    sf_daily = daily_accumulated_totals(sf_point, year, month)

    precip_mm = tp_daily["total_m"].sum(skipna=True) * 1000
    snowfall_mm = sf_daily["total_m"].sum(skipna=True) * 1000
    n_days_flagged = int(tp_daily["flagged"].sum())
    expected_days = pd.Period(f"{year}-{month:02d}").days_in_month

    # --- instantaneous: temperature, dewpoint, skin temp, wind, pressure, snow depth ---
    t2m_daily = daily_instant_stats(groups, "t2m", lat, lon, year, month)
    d2m_daily = daily_instant_stats(groups, "d2m", lat, lon, year, month)
    skt_daily = daily_instant_stats(groups, "skt", lat, lon, year, month)
    u10_daily = daily_instant_stats(groups, "u10", lat, lon, year, month)
    v10_daily = daily_instant_stats(groups, "v10", lat, lon, year, month)
    sp_daily = daily_instant_stats(groups, "sp", lat, lon, year, month)
    sde_daily = daily_instant_stats(groups, "sde", lat, lon, year, month)

    tmean_c = (t2m_daily["mean"] - 273.15).mean()
    tmin_c = (t2m_daily["min"] - 273.15).mean()
    tmax_c = (t2m_daily["max"] - 273.15).mean()
    dewpoint_c = (d2m_daily["mean"] - 273.15).mean()
    skin_temp_c = (skt_daily["mean"] - 273.15).mean()
    surface_pressure = sp_daily["mean"].mean()
    snow_depth = sde_daily["mean"].mean()

    # Wind speed from the DAILY MEAN u/v components, matching production's
    # add_derived_bands() order of operations -- not the mean of hourly speeds.
    daily_wind_speed = np.hypot(u10_daily["mean"], v10_daily["mean"])
    wind_speed_10m = daily_wind_speed.mean()

    n_hours_captured = int(t2m_daily["count"].sum())
    expected_hours = expected_days * 24

    return {
        "geoid": case["geoid"], "county": case["county"], "state": case["state"],
        "year": year, "month": month, "station_id": case["station_id"],
        "grid_lat_used": lat, "grid_lon_used": lon,
        "used_fallback_grid_cell": resolved["used_fallback"],
        "fallback_distance_deg": resolved["fallback_distance_deg"],
        "n_hours_captured": n_hours_captured, "expected_hours": expected_hours,
        "n_days_flagged": n_days_flagged, "expected_days": expected_days,
        "precip_mm": precip_mm, "snowfall_mm": snowfall_mm,
        "tmean_c": tmean_c, "tmin_c": tmin_c, "tmax_c": tmax_c,
        "dewpoint_c": dewpoint_c, "skin_temp_c": skin_temp_c,
        "wind_speed_10m": wind_speed_10m, "snow_depth": snow_depth,
        "surface_pressure": surface_pressure,
    }


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    """
    Processes whichever ground-truth GRIB files are currently present and
    merges the result into OUTPUT_PATH, rather than requiring all three at
    once. Rerunning after a new file lands reprocesses only that file's
    case and leaves other cases' rows untouched.
    """
    paths = sorted(INPUT_DIR.glob("*.grib"))
    if not paths:
        raise FileNotFoundError(f"No .grib files found in {INPUT_DIR}")

    print(f"Found {len(paths)} downloaded GRIB file(s) in {INPUT_DIR}")

    matched = {
        case["geoid"]: path
        for case in GROUND_TRUTH_CASES
        for path in paths
        if case["station_id"] in path.name
    }

    missing = [c for c in GROUND_TRUTH_CASES if c["geoid"] not in matched]
    if missing:
        print(
            f"\n{len(missing)} of {len(GROUND_TRUTH_CASES)} ground-truth case(s) have no "
            "matching downloaded file yet -- processing the rest:"
        )
        for c in missing:
            print(f"  missing: {c['county']} County, {c['state']} ({c['year']}-{c['month']:02d})")

    rows = []
    for case in GROUND_TRUTH_CASES:
        if case["geoid"] not in matched:
            continue
        path = matched[case["geoid"]]
        groups = load_groups(path)
        rows.append(process_case(case, path, groups))

    if not rows:
        raise RuntimeError("No ground-truth cases could be processed -- check downloads in " f"{INPUT_DIR}")

    new_result = pd.DataFrame(rows)

    if OUTPUT_PATH.exists():
        existing = pd.read_csv(OUTPUT_PATH, dtype={"geoid": str})
        existing = existing[~existing["geoid"].isin(new_result["geoid"])]  # drop rows we're about to replace
        result = pd.concat([existing, new_result], ignore_index=True).sort_values("geoid").reset_index(drop=True)
    else:
        result = new_result

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(OUTPUT_PATH, index=False)

    print(f"\nWrote {len(result)} station-month row(s) to: {OUTPUT_PATH}")

    flagged = result[(result["n_days_flagged"] > 0) | (result["n_hours_captured"] < result["expected_hours"])]
    if not flagged.empty:
        print(
            "\nNote: incomplete coverage on these rows (expected for the last day of the "
            "requested range unless an extra trailing day was downloaded):"
        )
        print(flagged[["geoid", "county", "year", "month", "n_days_flagged",
                        "n_hours_captured", "expected_hours"]].to_string(index=False))


if __name__ == "__main__":
    main()
