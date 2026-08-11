"""
Small-scale ERA5-Land extraction test (IL/IN, 2020-2021), used to
validate unit-conversion decisions before they're carried into the
full-scale ERA5 script.

- Validates several decisions before applying them in 03: using
  ECMWF/ERA5_LAND/DAILY_AGGR (only dataset with all required bands),
  converting Kelvin->Celsius and precip/snowfall meters->mm inline (a new
  pattern for this project -- PRISM needed no such conversion), and
  computing wind speed from u/v components.
- Adds tmin_c/tmax_c daily extremes as a test addition, to check whether
  they're worth carrying into the full pipeline (PRISM already covers
  tmin/tmax, so this may be redundant -- flagged for the team).
- Run this before 04_extract_era5_county.py; don't launch
  a full-scale run until a small test run succeeds.
"""

import logging
from pathlib import Path

import ee

import gee_extract_utils as geeutil

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

ERA5_COLLECTION = "ECMWF/ERA5_LAND/DAILY_AGGR"

# Illinois = 17; Indiana = 18 -- same states as 01_test_prism_extract.py,
# so results are directly comparable to the already-validated PRISM test.
STATE_FIPS = ["17", "18"]

YEARS = [2020, 2021]

# Raw bands read from the collection before derived-band preprocessing.
RAW_BANDS = [
    "temperature_2m",
    "temperature_2m_min",
    "temperature_2m_max",
    "dewpoint_temperature_2m",
    "skin_temperature",
    "u_component_of_wind_10m",
    "v_component_of_wind_10m",
    "snow_depth",
    "snowfall_sum",
    "surface_pressure",
    "total_precipitation_sum",
]

# Final band names after unit conversion / derived-band computation (see
# module docstring for the reasoning behind each choice).
FINAL_BANDS = [
    "tmean_c",
    "tmin_c",
    "tmax_c",
    "dewpoint_c",
    "skin_temp_c",
    "wind_speed_10m",
    "snow_depth",
    "snowfall_mm",
    "surface_pressure",
    "precip_mm",
]

# ERA5-Land's native pixel size is approximately 11.1 km.
SCALE_METERS = 11132.0
TILE_SCALE = 4

DRIVE_FOLDER = "earth_engine_era5_test"

RUN_TIMESTAMP = geeutil.run_timestamp()

REPO_ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = REPO_ROOT / "dataCSV" / "ERA5" / "test"
LOG_PATH = STATE_DIR / "logs" / f"era5_test_extract_{RUN_TIMESTAMP}.log"

MOVE_DESTINATION_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/ERA5/test",  # Kodama server
    REPO_ROOT / "dataRAW" / "ERA5" / "test",  # personal dev repo fallback
]

POLL_INTERVAL_SECONDS = 15


# ---------------------------------------------------------------------
# ERA5-specific: unit conversion + derived bands
# ---------------------------------------------------------------------

def add_derived_bands(image):
    """
    Convert temperature bands Kelvin -> Celsius, precip/snowfall
    meters -> mm, and compute wind speed from the u/v components. See
    module docstring for why these conversions happen here rather than
    a later harmonization step -- this is the thing this test script
    exists to validate.
    """
    image = ee.Image(image)

    tmean_c = image.select("temperature_2m").subtract(273.15).rename("tmean_c")
    tmin_c = image.select("temperature_2m_min").subtract(273.15).rename("tmin_c")
    tmax_c = image.select("temperature_2m_max").subtract(273.15).rename("tmax_c")
    dewpoint_c = (
        image.select("dewpoint_temperature_2m").subtract(273.15).rename("dewpoint_c")
    )
    skin_temp_c = image.select("skin_temperature").subtract(273.15).rename("skin_temp_c")

    wind_speed_10m = (
        image.select("u_component_of_wind_10m")
        .pow(2)
        .add(image.select("v_component_of_wind_10m").pow(2))
        .sqrt()
        .rename("wind_speed_10m")
    )

    precip_mm = (
        image.select("total_precipitation_sum").multiply(1000).rename("precip_mm")
    )
    snowfall_mm = image.select("snowfall_sum").multiply(1000).rename("snowfall_mm")

    # addBands() on `image` preserves image-level metadata (including
    # system:time_start), so no explicit copyProperties() is needed.
    return image.addBands(
        [
            tmean_c, tmin_c, tmax_c, dewpoint_c, skin_temp_c,
            wind_speed_10m, precip_mm, snowfall_mm,
        ]
    )


def build_year_image_collection(year):
    """Return the ERA5-Land ImageCollection for one calendar year, prepped."""
    start_date = ee.Date.fromYMD(year, 1, 1)
    end_date = start_date.advance(1, "year")

    return (
        ee.ImageCollection(ERA5_COLLECTION)
        .filterDate(start_date, end_date)
        .select(RAW_BANDS)
        .map(add_derived_bands)
        .select(FINAL_BANDS)
    )


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    geeutil.setup_logging(LOG_PATH)
    geeutil.initialize_earth_engine(EE_PROJECT)

    counties = geeutil.get_counties(state_fips_list=STATE_FIPS)

    # Small client-side check -- retrieves metadata only, not the full
    # extraction.
    county_count = counties.size().getInfo()
    logging.info("Selected %d counties.", county_count)

    tasks = []

    # Nested loop: one export task per state/year combination (2x2 = 4).
    for state_fips in STATE_FIPS:
        state_abbrev = geeutil.CONUS_STATE_ABBREVIATIONS[state_fips]
        state_counties = geeutil.filter_counties_by_state(counties, state_fips)

        for year in YEARS:
            logging.info("Building ERA5 extraction for %s %d...", state_abbrev, year)

            image_collection = build_year_image_collection(year)
            annual_results = geeutil.build_period_collection(
                image_collection=image_collection,
                counties=state_counties,
                bands=FINAL_BANDS,
                scale_meters=SCALE_METERS,
                tile_scale=TILE_SCALE,
                extra_property_names=None,  # no ERA5 equivalent of dataset_type
            )

            filename = f"era5_county_daily_{state_abbrev}_{year}_{RUN_TIMESTAMP}"
            task = geeutil.start_export(
                collection=annual_results,
                description=filename,
                drive_folder=DRIVE_FOLDER,
                filename=filename,
                selectors=geeutil.ID_COLS + ["date", "year"] + FINAL_BANDS,
            )
            tasks.append(task)

    logging.info("Monitoring export progress...")
    geeutil.monitor_export_tasks(tasks, poll_interval_seconds=POLL_INTERVAL_SECONDS)

    try:
        destination = geeutil.resolve_data_root(MOVE_DESTINATION_CANDIDATES)
        logging.info(
            "Exports have finished. Google Drive folder: %s. Once downloaded, "
            "move the CSVs into: %s", DRIVE_FOLDER, destination,
        )
    except FileNotFoundError:
        logging.warning(
            "Exports have finished. Google Drive folder: %s. Could not resolve "
            "a local destination folder from %s -- move the CSVs manually.",
            DRIVE_FOLDER, MOVE_DESTINATION_CANDIDATES,
        )


if __name__ == "__main__":
    main()
