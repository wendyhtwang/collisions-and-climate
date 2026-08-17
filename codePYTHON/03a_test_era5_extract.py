"""
Small-scale ERA5-Land extraction test (IL/IN, 2020-2021), used to
validate unit-conversion decisions before they're carried into the
full-scale ERA5 script.

- Validates several decisions before applying them in 03a: using
  ECMWF/ERA5_LAND/DAILY_AGGR (only dataset with all required bands),
  converting Kelvin->Celsius and precip/snowfall meters->mm inline (a new
  pattern for this project -- PRISM needed no such conversion), and
  computing wind speed from u/v components.
- Adds tmin_c/tmax_c daily extremes as a test addition, to check whether
  they're worth carrying into the full pipeline (PRISM already covers
  tmin/tmax, so this may be redundant -- flagged for the team).
- Run this before 04a_extract_era5_county.py; don't launch
  a full-scale run until a small test run succeeds.
"""

import logging
from pathlib import Path

import gee_extract_utils as geeutil
from era5_extract_utils import ERA5_COLLECTION, RAW_BANDS, FINAL_BANDS, add_derived_bands

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

# Illinois = 17; Indiana = 18 -- same states as 01a_test_prism_extract.py,
# so results are directly comparable to the already-validated PRISM test.
STATE_FIPS = ["17", "18"]

YEARS = [2020, 2021]

# ERA5_COLLECTION, RAW_BANDS, FINAL_BANDS, and add_derived_bands() are
# shared with 04a_extract_era5_county.py -- see era5_extract_utils.py.
# This test script exists specifically to validate that logic before it
# runs at full CONUS scale, so it must run the exact same code as 04a, not
# an independently-maintained copy of it.

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

            image_collection = geeutil.build_year_image_collection(
                ERA5_COLLECTION, year, FINAL_BANDS,
                raw_bands=RAW_BANDS, preprocess_fn=add_derived_bands,
            )
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
