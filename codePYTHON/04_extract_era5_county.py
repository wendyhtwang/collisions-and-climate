"""
Full-scale ERA5-Land extraction for all CONUS counties, 1981-2025 --
mirrors 02_extract_prism_county.py's structure for the parallel weather
dataset.

- Uses `ECMWF/ERA5_LAND/DAILY_AGGR`, not plain `ERA5/DAILY`: only the
  -Land version has snowfall, snow depth, and skin temperature bands, at
  finer resolution (~11.1km vs ~28km).
- Converts temperature bands Kelvin->Celsius and precipitation/snowfall
  meters->mm **inline during extraction**, to match PRISM's Celsius/mm
  conventions. Wind speed is computed from u/v components since
  ERA5-Land has no direct wind-speed band. `surface_pressure` is left in
  native Pa. 
- Adds tmin_c/tmax_c (daily extremes), which weren't in the original ERA5
  variable list, after validating them in the small-scale test -- worth
  confirming with the team whether this duplicates PRISM's own tmin/tmax.
- Shares gee_extract_utils.py's resumability-manifest (written
  incrementally as each task completes) and shared-Drive-folder mechanics
  with the PRISM script.
- Large job -- do not run against the full YEARS range without explicit
  sign-off; test with 1-2 years first.
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

# Same CONUS + DC county set as the PRISM extraction.
STATE_FIPS = geeutil.CONUS_STATE_FIPS

# Same 1981-2025 period as the PRISM extraction (ERA5-Land itself goes
# back to 1950, but we only need 1981 on to match PRISM's start).
YEARS = list(range(1981, 2026))

DRIVE_FOLDER = "earth_engine_era5_full"

RUN_TIMESTAMP = geeutil.run_timestamp()

REPO_ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = REPO_ROOT / "dataCSV" / "ERA5"
MANIFEST_PATH = STATE_DIR / "era5_full_completed_years.json"
LOG_PATH = STATE_DIR / "logs" / f"era5_full_extract_{RUN_TIMESTAMP}.log"

MOVE_DESTINATION_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/ERA5",  # Kodama server
    REPO_ROOT / "dataRAW" / "ERA5",  # personal dev repo fallback
]

POLL_INTERVAL_SECONDS = 30


# ---------------------------------------------------------------------
# ERA5-specific: unit conversion + derived bands
# ---------------------------------------------------------------------

def add_derived_bands(image):
    """
    Convert temperature bands Kelvin -> Celsius, precip/snowfall
    meters -> mm, and compute wind speed from the u/v components. See
    module docstring for why these conversions happen here vs. left for
    a later harmonization step.
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

    county_count = counties.size().getInfo()
    logging.info("Selected %d CONUS counties.", county_count)

    completed_years = geeutil.load_completed_periods(MANIFEST_PATH)
    years_to_run = [y for y in YEARS if str(y) not in completed_years]

    if not years_to_run:
        logging.info(
            "All %d years already completed per manifest at %s -- nothing to do.",
            len(YEARS), MANIFEST_PATH,
        )
        return

    if completed_years:
        logging.info(
            "Resuming: %d year(s) already completed, %d remaining.",
            len(completed_years), len(years_to_run),
        )

    # Build all export specs before submitting -- see
    # start_exports_to_shared_folder() in gee_extract_utils.py for why.
    export_specs = []
    spec_years = []

    for year in years_to_run:
        logging.info("Building ERA5 extraction for %d...", year)

        image_collection = build_year_image_collection(year)
        annual_results = geeutil.build_period_collection(
            image_collection=image_collection,
            counties=counties,
            bands=FINAL_BANDS,
            scale_meters=SCALE_METERS,
            tile_scale=TILE_SCALE,
            extra_property_names=None,  # no ERA5 equivalent of dataset_type
        )

        filename = f"era5_county_daily_{year}_{RUN_TIMESTAMP}"
        export_specs.append(dict(
            collection=annual_results,
            description=filename,
            filename=filename,
            selectors=geeutil.ID_COLS + ["date", "year"] + FINAL_BANDS,
        ))
        spec_years.append(year)

    tasks = geeutil.start_exports_to_shared_folder(export_specs, drive_folder=DRIVE_FOLDER)
    task_year_by_id = {task.id: year for task, year in zip(tasks, spec_years)}

    logging.info("Monitoring %d export task(s)...", len(tasks))
    failed_task_ids = geeutil.monitor_export_tasks(
        tasks,
        poll_interval_seconds=POLL_INTERVAL_SECONDS,
        on_task_complete=lambda task_id: geeutil.mark_period_complete(
            MANIFEST_PATH, task_year_by_id[task_id]
        ),
    )

    if failed_task_ids:
        failed_years = sorted(task_year_by_id[tid] for tid in failed_task_ids)
        logging.warning(
            "%d year(s) did NOT complete successfully and were not marked "
            "done in the manifest -- rerun this script to retry them: %s",
            len(failed_years), failed_years,
        )

    try:
        destination = geeutil.resolve_data_root(MOVE_DESTINATION_CANDIDATES)
        logging.info("Once exports finish, sync/move the Drive CSVs into: %s", destination)
    except FileNotFoundError:
        logging.warning(
            "Could not resolve a local destination folder from %s -- "
            "move the CSVs manually.", MOVE_DESTINATION_CANDIDATES,
        )


if __name__ == "__main__":
    main()
