"""
Parses the independently-downloaded ERA5-Land hourly GRIB files (pulled
directly from the Copernicus CDS, not GEE) for the ground-truth stations,
and aggregates each to an "ERA5-at-point" county-year-month value -- the
ERA5 counterpart to PRISM's Data Explorer point lookup used in
ground_truth_spotcheck_summary.xlsx.

- Independent of GEE and of this repo's own extraction code
  (04_extract_era5_county.py / gee_extract_utils.py): the files here were
  downloaded straight from https://cds.climate.copernicus.eu, so a bug
  shared between the production pipeline and this check wouldn't be
  invisible to it.
- Matches each downloaded file to a ground-truth case by its EMBEDDED
  bounding box and time range, not by its filename. A real mismatch was
  found during development (a file named for Moore County, TN / 1999-06
  actually contained Blackford County, IN / 2021-12 data -- almost
  certainly a save-dialog mix-up when downloading from the CDS website).
  Trusting filenames here would have silently corrupted the comparison,
  so filenames are only used as a human-readable hint; the actual
  station/period match is verified against the file's own coordinates
  and dates, and the script errors loudly on any mismatch.
- Uses `cfgrib.open_datasets()` (plural), not `open_dataset()`: ERA5-Land
  hourly CDS downloads bundle variables with incompatible GRIB editions/
  hypercubes (observed here: accumulated + most instantaneous variables
  in one group, skin_temperature in a second, snow_depth in a third with
  longitude in 0-360 convention instead of -180/180). `open_dataset()`
  raises trying to merge these; `open_datasets()` returns them as
  separate, internally-consistent groups.
- Precipitation/snowfall are ERA5(-Land)'s classic "accumulated since the
  reference time" fields: each day's own reference block (time=that day
  00 UTC, step=1..24) accumulates from zero, so a day's total is the
  step=24 value of ITS OWN block, not a diff-of-consecutive-hours
  reconstruction. Confirmed empirically against the Blackford test file
  (values were monotonically non-decreasing within a block, resetting at
  each new reference day).
- Known boundary gap: the last day of the requested month is often
  missing its own step=24 value, because that value's valid time (next
  month, 00:00) falls outside the requested day range and CDS doesn't
  deliver it. Falls back to the latest available step for that day and
  flags the row (`n_days_flagged` / per-day fractional-hour note) rather
  than silently under-counting or dropping the day. Re-downloading with
  one extra trailing day would remove this gap entirely if exact
  precision on the last day matters more than avoiding a re-submit.
- Instantaneous variables (temperature, dewpoint, skin temp, wind
  components, surface pressure, snow depth) are bucketed by `valid_time`
  (time + step), not by the raw `time` coordinate -- `time` is the
  reference base, not the hour the value actually describes.
- Daily tmin/tmax/tmean and wind speed follow production's exact order of
  operations (04_extract_era5_county.py's add_derived_bands(), applied to
  ECMWF/ERA5_LAND/DAILY_AGGR): tmin/tmax/tmean are the day's min/mean/max
  of the 24 hourly readings; wind speed is computed from the DAILY MEAN
  u/v components (speed-of-the-mean-vector), not the mean of hourly
  speeds -- matching how add_derived_bands() operates on an
  already-daily-aggregated image, not raw hourly images.
- Grid-cell selection uses nearest-neighbor to the station's exact
  coordinate, with an explicit distance check (errors if the nearest
  point is more than ~1.5 grid cells away) -- xarray's `.sel(...,
  method="nearest")` fails silently otherwise, which is exactly how the
  file mislabeling above would have gone undetected.
- ERA5-Land is LAND-ONLY: grid cells that are mostly open water are
  masked as NaN for every variable, at every hour -- unlike PRISM, which
  still produces an interpolated value everywhere in CONUS. This bit the
  Chowan County, NC case: the nearest grid cell to the Edenton station
  (36.0, -76.6) is masked entirely (confirmed by inspecting the raw
  values -- 100% NaN across all 768 time/step combinations), because
  that cell sits on Albemarle Sound, the same water-dominated cell
  PRISM's own ground-truth notes already called out for this station.
  `resolve_valid_point()` checks the nearest cell's NaN fraction against
  `t2m` first and, if it's fully/mostly masked, searches the rest of the
  downloaded box for the nearest cell with real data, flagging the
  row (`used_fallback_grid_cell`, `fallback_distance_deg`) rather than
  silently returning all-NaN monthly stats. The same resolved coordinate
  is then reused for every variable for that case, so all bands come
  from one consistent grid cell rather than each variable independently
  picking its own.
- Monthly aggregation convention matches 05b_aggregate_era5_daily_to_monthly.py
  exactly: precip_mm/snowfall_mm summed, everything else averaged.
"""

from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
import cfgrib

# ---------------------------------------------------------------------
# Ground-truth cases -- keep in sync with 07g_filter_era5_ground_truth_sample.py,
# 07h_compare_era5_ground_truth.py, and the PRISM version
# (07e_filter_prism_ground_truth_sample.py) / ground_truth_spotcheck_summary.xlsx.
# Coordinates are rounded to 1 decimal (from the PRISM ground-truth summary);
# that's within one ERA5-Land grid cell (0.1 deg) of the true station
# location, so nearest-neighbor selection below is robust to it, but swap
# in exact coordinates from ghcnd-stations.txt if you want to remove that
# margin entirely.
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

# How far (in degrees) the nearest grid point may sit from the station's
# known coordinate before we treat it as a real mismatch rather than
# rounding noise. ERA5-Land grid spacing is 0.1 deg, so 1.5x that catches
# "wrong file" cases without flagging normal nearest-neighbor snapping.
MAX_POINT_DISTANCE_DEG = 0.15

# When the nearest cell is masked (land-sea mask -- see module docstring),
# how far we're willing to search the downloaded box for a valid one, and
# how much NaN in a cell's time series counts as "masked" rather than just
# the expected few missing hours at the request boundary.
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
    normalize any 0-360 longitude convention to -180/180 so every group
    can be indexed the same way.

    `indexpath=""` disables cfgrib's on-disk .idx sidecar cache -- in a
    cloud-synced folder (iCloud/Dropbox/etc, which is where these
    downloads land), a stale or permission-locked .idx file can make
    cfgrib silently read garbage instead of re-parsing the actual GRIB
    bytes. Re-parsing the file each run costs a little time but avoids
    that failure mode entirely.
    """
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
# Station/file matching -- by embedded content, not filename (see module
# docstring for why filenames aren't trusted here)
# ---------------------------------------------------------------------

def file_matches_case(groups: list[xr.Dataset], case: dict) -> bool:
    ds = groups[0]
    lat, lon = ds.latitude.values, ds.longitude.values
    lat_in_box = lat.min() - 0.01 <= case["station_lat"] <= lat.max() + 0.01
    lon_in_box = lon.min() - 0.01 <= case["station_lon"] <= lon.max() + 0.01

    times = pd.to_datetime(ds.time.values)
    year_month_present = ((times.year == case["year"]) & (times.month == case["month"])).any()

    return lat_in_box and lon_in_box and year_month_present


def match_files_to_cases(paths: list[Path]) -> dict[str, tuple[Path, list[xr.Dataset]]]:
    """
    Return {geoid: (path, groups)}, matching each ground-truth case to
    exactly one file by content. Returns the already-parsed groups
    alongside the path so process_case() doesn't have to re-parse the
    same ~1MB GRIB file a second time (cfgrib parsing is the slow part
    here with on-disk index caching disabled -- see load_groups()).
    """
    matched: dict[str, tuple[Path, list[xr.Dataset]]] = {}
    for path in paths:
        try:
            groups = load_groups(path)
        except Exception as exc:
            print(
                f"  WARNING: couldn't read {path.name} ({type(exc).__name__}: {exc}) -- "
                "skipping it. This usually means the download is still in progress/incomplete "
                "(common with cloud-synced folders) or the file didn't finish downloading; "
                "rerun once it's fully synced."
            )
            continue

        hits = [case for case in GROUND_TRUTH_CASES if file_matches_case(groups, case)]

        if len(hits) == 0:
            print(f"  WARNING: {path.name} doesn't match any configured ground-truth case's "
                  f"box/period -- skipping. (lat={groups[0].latitude.values}, "
                  f"lon={groups[0].longitude.values}, "
                  f"time={pd.to_datetime(groups[0].time.values).min()} to "
                  f"{pd.to_datetime(groups[0].time.values).max()})")
            continue
        if len(hits) > 1:
            raise ValueError(
                f"{path.name} matches more than one ground-truth case's box/period "
                f"({[h['geoid'] for h in hits]}) -- boxes may overlap; resolve manually."
            )

        case = hits[0]
        claimed_station, claimed_year, claimed_month = parse_filename(path)
        if claimed_station != case["station_id"] or claimed_year != case["year"] or claimed_month != case["month"]:
            print(
                f"  NOTE: {path.name}'s filename claims station={claimed_station} "
                f"{claimed_year}-{claimed_month:02d}, but its embedded coordinates/dates "
                f"actually match {case['county']} County, {case['state']} "
                f"(station {case['station_id']}, {case['year']}-{case['month']:02d}). "
                "Processing it as the latter -- consider renaming the file to avoid confusion."
            )

        if case["geoid"] in matched:
            raise ValueError(
                f"Both {matched[case['geoid']][0].name} and {path.name} match the same "
                f"ground-truth case (GEOID {case['geoid']}) -- remove the stale/duplicate file."
            )
        matched[case["geoid"]] = (path, groups)

    return matched


def parse_filename(path: Path) -> tuple[str, int, int] | tuple[None, None, None]:
    m = re.match(r"^([A-Za-z0-9]+)_(\d{4})_(\d{2})\.grib$", path.name)
    if not m:
        return (None, None, None)
    station_id, year, month = m.groups()
    return station_id, int(year), int(month)


# ---------------------------------------------------------------------
# Point selection
# ---------------------------------------------------------------------

def resolve_valid_point(groups: list[xr.Dataset], lat: float, lon: float) -> dict:
    """
    Find the grid cell to actually use for this station: the nearest one
    if it has real data, otherwise the nearest cell (within
    MAX_FALLBACK_DISTANCE_DEG) that isn't masked out by ERA5-Land's
    land-sea mask. Checked against `t2m` as a representative variable --
    the mask is the same static land/sea field for every variable in a
    given ERA5-Land file, so one check is enough.
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
    Daily totals for an accumulated field (precip, snowfall): each day's
    own reference-time block accumulates from zero across its 24 steps,
    so the day's total is that block's last available step. Flags days
    where step=24 itself wasn't available (see module docstring -- this
    is expected for the last day of the requested range) and falls back
    to the latest step that IS available.
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

    # Wind speed from the DAILY MEAN u/v components (speed-of-the-mean-vector),
    # matching production's add_derived_bands() order of operations -- not
    # the mean of hourly speeds. See module docstring.
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
    once -- useful since these are large individual CDS downloads that
    tend to finish one at a time. Rerunning after a new file lands
    reprocesses only that file's case and leaves previously-computed rows
    for other cases untouched.
    """
    paths = sorted(INPUT_DIR.glob("*.grib"))
    if not paths:
        raise FileNotFoundError(f"No .grib files found in {INPUT_DIR}")

    # Optional: process only files whose name contains this substring
    # (e.g. a station ID). Parsing each ~1MB file takes ~30s in this
    # environment, so this is handy for reprocessing just one file
    # without waiting on the others: SPOTCHECK_FILTER=USC00123777 python3 07f_...
    name_filter = __import__("os").environ.get("SPOTCHECK_FILTER")
    if name_filter:
        paths = [p for p in paths if name_filter in p.name]
        print(f"SPOTCHECK_FILTER={name_filter!r} -- restricting to {len(paths)} file(s)")

    print(f"Found {len(paths)} downloaded GRIB file(s) in {INPUT_DIR}")
    print("Matching files to ground-truth cases by embedded coordinates/dates (not filename):")
    matched = match_files_to_cases(paths)

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
        path, groups = matched[case["geoid"]]
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
            "\nNote: incomplete coverage on these rows (see module docstring -- expected for "
            "the last day of the requested range unless an extra trailing day was downloaded):"
        )
        print(flagged[["geoid", "county", "year", "month", "n_days_flagged",
                        "n_hours_captured", "expected_hours"]].to_string(index=False))


if __name__ == "__main__":
    main()
