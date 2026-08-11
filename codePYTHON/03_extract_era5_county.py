"""
Full-scale ERA5 extraction: CONUS, 1981-2025, county mean.

Extracts daily county-level mean ERA5-Land weather values for:
- All CONUS counties (48 states + DC; excludes AK, HI, territories) --
  same county set as 02_extract_prism_county.py
- 1981-01-01 through 2025-12-31 (45 calendar years)
- Every ERA5 variable Phase 3 asks for: 2m temperature, 2m dewpoint
  temperature, total precipitation, snowfall, snow depth, 10m wind
  speed, surface pressure, skin temperature -- plus daily 2m temperature
  min/max (tmin_c, tmax_c), added 2026-08-05 after validating alongside
  the rest in 03a_test_era5_extract.py. Phase 3's ERA5 list doesn't call
  for daily min/max the way PRISM's spec does (tmin, tmax); confirm with
  the team whether PRISM already covering tmin/tmax makes this redundant.

DATASET CHOICE: ECMWF/ERA5_LAND/DAILY_AGGR (not ECMWF/ERA5/DAILY).
Plain ERA5/DAILY does NOT have snowfall, snow depth, or skin
temperature -- confirmed against the Earth Engine catalog. ERA5-Land
has all of the requested variables in one collection, at finer native
resolution (~11.1km vs ERA5's ~28km), covering 1950-present. Flag to
Nicole/Eyal if plain ERA5 (not -Land) was actually intended for a
specific reason (e.g. matching a different published product).

UNIT/BAND NOTES (flagging for the data dictionary -- confirm with
Eyal rather than assume these choices are final):
- temperature_2m, temperature_2m_min, temperature_2m_max,
  dewpoint_temperature_2m, skin_temperature are natively Kelvin.
  Converted to Celsius here (tmean_c, tmin_c, tmax_c, dewpoint_c,
  skin_temp_c) to match PRISM's Celsius convention, since having one
  dataset in K and the other in C invites mistakes downstream. This IS
  a light processing step happening inside "extraction" rather than a
  separate harmonization stage -- flagging in case the project's
  raw/build separation wants this deferred instead. Note this is a new
  pattern for this project, not a continuation of one:
  02_extract_prism_county.py does zero unit conversion, because PRISM's
  native units already matched the targets.
- wind_speed_10m is computed as sqrt(u^2 + v^2) from
  u_component_of_wind_10m / v_component_of_wind_10m (m/s )-- ERA5-Land
  has no single "wind speed" band, only vector components.
- total_precipitation_sum and snowfall_sum are natively meters of water
  equivalent. CHANGE (2026-08-05): now converted to mm here
  (precip_mm, snowfall_mm) to match PRISM's ppt (mm) convention, rather
  than left in meters and deferred to 05_build_derived_weather_vars.py
  as originally planned -- m->mm is the same kind of linear conversion
  as the temperature one, so there's no clear reason to treat it
  differently. Validated first in 03a_test_era5_extract.py before being
  carried in here.
- surface_pressure is left in Pa (native units).
- No ERA5-Land equivalent of PRISM's 'dataset_type' vintage flag exists
  in the catalog documentation reviewed -- omitted from extra_property_names.
- All of the above are still flagged for Eyal's sign-off
  before being treated as final in the shared data dictionary.

The mechanics (auth, county reduction, export, progress monitoring,
logging, resumability) live in gee_extract_utils.py, shared with
02_extract_prism_county.py -- see that file's header for why monthly
aggregation happens client-side in 04_aggregate_daily_to_monthly.py
rather than server-side in Earth Engine.

Note: this is a large job (45 export tasks, full CONUS). Do not run against
the full YEARS range without explicit sign-off -- test with 1-2 years
first.

Google Drive folder: earth_engine_era5_full
After completion, sync/move the CSVs to:
  Kodama: /mnt/data_f/AnimalCollisionsWeatherData/ERA5
  (personal dev repo fallback: dataRAW/ERA5)
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
# TEMPORARY (2026-08-06): trimmed to 2010-2025 -- 1981-2009 already
# completed and confirmed via checkmarks in the GEE Tasks panel, but the
# manifest at MANIFEST_PATH was never written (the original run's
# terminal was closed before all 45 tasks finished, and the manifest is
# only written after monitor_export_tasks() sees every task reach a
# terminal state -- see that function's docstring). Cancel the 16
# pending 2010-2025 tasks in the Tasks panel BEFORE rerunning this
# script, so this doesn't submit duplicates alongside them. REVERT to
# YEARS = list(range(1981, 2026)) once this run completes.
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

    # CHANGE: build all export specs first, without submitting, then hand
    # them to start_exports_to_shared_folder() so every year lands in one
    # Drive folder instead of racing to create duplicates -- see
    # gee_extract_utils.py for why (same fix applied to the PRISM script
    # after the 2020/2021 CONUS run created two "earth_engine_prism_full"
    # folders).
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
        tasks, poll_interval_seconds=POLL_INTERVAL_SECONDS
    )

    for task in tasks:
        if task.id not in failed_task_ids:
            geeutil.mark_period_complete(MANIFEST_PATH, task_year_by_id[task.id])

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
