"""
Identifies candidate CONUS counties served by only one (or very few) NOAA
weather stations, as candidates for a ground-truth spot check of PRISM
against real station data (per the 08.07.26 Fri team meeting).

- Uses NOAA GHCN-Daily station density as a proxy for how many stations
  fed PRISM's interpolation for that county (PRISM's exact input station
  list isn't published, so this is an imperfect but reasonable stand-in).
- Requires a candidate station to report precipitation, max temp, and min
  temp for every one of the target years.
- Ranks candidates by land area ascending -- a smaller county means the
  one station covers more of it, a better ground-truth case.
- Excludes independent cities (e.g. Baltimore city, VA cities) even
  though they're legitimate Census county-equivalents: their stations are
  often urban/microclimate sites sitting inside well-instrumented metro
  areas, a poor fit for the isolated-rural-county case wanted. This is a
  name/code heuristic, not a guaranteed-correct classification, so
  candidates should still be reviewed by eye.
- Doesn't auto-pick a final county -- outputs a candidate list for manual
  review. No Earth Engine calls; needs real internet access, so run this
  locally (e.g. on Kodama), not from a network-restricted sandbox.
"""

import io
from pathlib import Path

import geopandas as gpd
import pandas as pd
import requests

import gee_extract_utils as geeutil  # only for CONUS_STATE_FIPS -- no `ee` calls made

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

GHCND_STATIONS_URL = "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-stations.txt"
GHCND_INVENTORY_URL = "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-inventory.txt"
COUNTY_SHP_URL = "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_20m.zip"

# Matches 07_export_prism_monthly_spotcheck.py's SPOT_CHECK_YEARS, so a
# county picked here can slot directly into that same sample.
TARGET_YEARS = [2000, 2010, 2020, 2021, 2025]
REQUIRED_ELEMENTS = ["PRCP", "TMAX", "TMIN"]  # station must report all of these

# Eyal: "just 1 (or very few)" -- start strict at 1, loosen (e.g. to 2 or 3)
# if that turns up too few/no candidates in practice.
MAX_STATIONS_PER_COUNTY = 1
TOP_N_TO_PRINT = 25

# Census LSAD codes for genuine county-type units: 06=County, 13=Parish,
# 03/04/05=AK City-and-Borough/Borough/Census Area, 12=Municipality.
# Allowlist (not a blocklist) so 25=independent city is excluded. Not yet
# verified against this file's exact vintage -- load_conus_counties()
# prints an LSAD -> example-name crosswalk each run so a wrong code here
# is visible immediately.
VALID_COUNTY_LSAD_CODES = {"06", "13", "03", "04", "05", "12"}

REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check" / "ground_truth_candidate_counties.csv"


# ---------------------------------------------------------------------
# GHCN-Daily station inventory (fixed-width) + per-element year coverage
# ---------------------------------------------------------------------

# Column positions per NOAA's ghcnd-stations.txt / ghcnd-inventory.txt
# format spec (see module docstring for the readme URL), converted from
# the spec's 1-indexed inclusive ranges to pandas.read_fwf's 0-indexed
# half-open [start, end) ranges.
STATION_COLSPECS = [(0, 11), (12, 20), (21, 30), (31, 37), (38, 40), (41, 71)]
STATION_NAMES = ["station_id", "lat", "lon", "elevation_m", "state", "station_name"]

INVENTORY_COLSPECS = [(0, 11), (12, 20), (21, 30), (31, 35), (36, 40), (41, 45)]
INVENTORY_NAMES = ["station_id", "lat", "lon", "element", "first_year", "last_year"]


def load_ghcnd_stations() -> pd.DataFrame:
    print(f"Downloading {GHCND_STATIONS_URL} ...")
    stations = pd.read_fwf(GHCND_STATIONS_URL, colspecs=STATION_COLSPECS, names=STATION_NAMES)
    # US-only (station IDs starting with "US"), matching this project's CONUS scope.
    return stations[stations["station_id"].str.startswith("US")].reset_index(drop=True)


def load_ghcnd_inventory() -> pd.DataFrame:
    print(f"Downloading {GHCND_INVENTORY_URL} ...")
    inventory = pd.read_fwf(GHCND_INVENTORY_URL, colspecs=INVENTORY_COLSPECS, names=INVENTORY_NAMES)
    return inventory[inventory["station_id"].str.startswith("US")].reset_index(drop=True)


def filter_stations_with_required_coverage(
    stations: pd.DataFrame, inventory: pd.DataFrame
) -> pd.DataFrame:
    """Keep only stations reporting every REQUIRED_ELEMENTS band, spanning every TARGET_YEARS year."""
    relevant = inventory[inventory["element"].isin(REQUIRED_ELEMENTS)]

    covers_target_years = relevant.groupby("station_id").apply(
        lambda g: all(
            ((g["first_year"] <= yr) & (g["last_year"] >= yr)).any() for yr in TARGET_YEARS
        ),
        include_groups=False,
    )
    has_all_elements = relevant.groupby("station_id")["element"].nunique() == len(REQUIRED_ELEMENTS)

    qualifying_ids = covers_target_years[covers_target_years & has_all_elements].index
    return stations[stations["station_id"].isin(qualifying_ids)].reset_index(drop=True)


# ---------------------------------------------------------------------
# County boundaries
# ---------------------------------------------------------------------

def load_conus_counties() -> gpd.GeoDataFrame:
    print(f"Downloading {COUNTY_SHP_URL} ...")
    resp = requests.get(COUNTY_SHP_URL, timeout=120)
    resp.raise_for_status()
    counties = gpd.read_file(io.BytesIO(resp.content))
    counties = counties[counties["STATEFP"].isin(geeutil.CONUS_STATE_FIPS)].reset_index(drop=True)

    # Print schema + LSAD -> example-name crosswalk so a bad code is
    # visible before trusting VALID_COUNTY_LSAD_CODES for this vintage.
    print(f"  Columns in downloaded county file: {list(counties.columns)}")
    if "LSAD" in counties.columns:
        print("  LSAD -> example county name(s):")
        for lsad, group in counties.groupby("LSAD"):
            print(f"    {lsad!r}: {group['NAME'].head(3).tolist()}")

    is_true_county = counties["LSAD"].isin(VALID_COUNTY_LSAD_CODES)
    n_excluded = (~is_true_county).sum()
    if n_excluded:
        print(
            f"  Excluding {n_excluded} independent-city/consolidated-city-county "
            f"unit(s) (LSAD not in {VALID_COUNTY_LSAD_CODES}) -- e.g.:",
            counties.loc[~is_true_county, "NAME"].head(5).tolist(),
        )
    return counties[is_true_county].reset_index(drop=True)


# ---------------------------------------------------------------------
# Spatial join: stations -> counties
# ---------------------------------------------------------------------

def count_stations_per_county(stations: pd.DataFrame, counties: gpd.GeoDataFrame) -> pd.DataFrame:
    station_points = gpd.GeoDataFrame(
        stations,
        geometry=gpd.points_from_xy(stations["lon"], stations["lat"]),
        crs="EPSG:4326",
    )
    counties = counties.to_crs("EPSG:4326")

    joined = gpd.sjoin(station_points, counties, how="inner", predicate="within")

    counts = (
        joined.groupby(["GEOID", "NAME", "LSAD", "STATEFP", "ALAND"])
        .agg(
            n_stations=("station_id", "count"),
            station_ids=("station_id", lambda s: ",".join(sorted(s))),
            station_names=("station_name", lambda s: " | ".join(sorted(s.str.strip()))),
        )
        .reset_index()
    )
    return counts


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    stations = load_ghcnd_stations()
    inventory = load_ghcnd_inventory()
    qualifying_stations = filter_stations_with_required_coverage(stations, inventory)
    print(
        f"{len(qualifying_stations):,} US station(s) report PRCP/TMAX/TMIN "
        f"across all of {TARGET_YEARS}."
    )

    counties = load_conus_counties()
    counts = count_stations_per_county(qualifying_stations, counties)

    candidates = counts[counts["n_stations"] <= MAX_STATIONS_PER_COUNTY].copy()
    candidates["aland_sq_mi"] = candidates["ALAND"].astype(float) / 2_589_988.11  # m^2 -> sq mi
    candidates = candidates.sort_values(["n_stations", "aland_sq_mi"])

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    candidates.to_csv(OUTPUT_PATH, index=False)
    print(
        f"\n{len(candidates):,} candidate county(-ies) with <= {MAX_STATIONS_PER_COUNTY} "
        f"qualifying station(s), saved to:\n  {OUTPUT_PATH}"
    )

    print(f"\nTop {TOP_N_TO_PRINT} smallest by land area:")
    print(
        candidates[
            ["NAME", "LSAD", "STATEFP", "GEOID", "n_stations", "aland_sq_mi", "station_ids", "station_names"]
        ]
        .head(TOP_N_TO_PRINT)
        .to_string(index=False)
    )


if __name__ == "__main__":
    main()
