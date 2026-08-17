"""
Small-scale PRISM extraction test (IL/IN, 2020-2021), used to validate the
extraction method before running it at full CONUS scale.

- Tests only 4 of PRISM's 7 bands and 2 states/2 years -- same states/years
  used by the ERA5 test script, so results are directly comparable.
- Kept in the repo as a fast sanity check to rerun whenever
  gee_extract_utils.py (the shared extraction module) changes, before
  trusting a full-scale run.
- Output has been validated against manual Earth Engine Console
  calculations -- see 01_verify_prism_gee_console.js.
"""

import logging
from pathlib import Path

import gee_extract_utils as geeutil

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

RUN_TIMESTAMP = geeutil.run_timestamp()

REPO_ROOT = Path(__file__).resolve().parents[1]

MOVE_DESTINATION_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/PRISM/test",  # Kodama server
    REPO_ROOT / "dataRAW" / "PRISM" / "test",  # personal dev repo fallback
]

# Illinois = 17; Indiana = 18
STATE_FIPS = ["17", "18"]

YEARS = [2020, 2021]

PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"

# Start small. These can be expanded later -- see 02_extract_prism_county.py
# for the full 7-band version.
BANDS = ["ppt", "tmean", "tmin", "tmax"]

# PRISM's nominal pixel size is approximately 4.6 km.
SCALE_METERS = 4638.3
TILE_SCALE = 4

# Google Drive folder name, where the CSV will be exported.
DRIVE_FOLDER = "earth_engine_prism_test"

# How often (in seconds) to poll Earth Engine for export task status
# while the progress bar is running.
POLL_INTERVAL_SECONDS = 15


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
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
            logging.info("Building extraction for %s %d...", state_abbrev, year)

            image_collection = geeutil.build_year_image_collection(PRISM_COLLECTION, year, BANDS)
            annual_results = geeutil.build_period_collection(
                image_collection=image_collection,
                counties=state_counties,
                bands=BANDS,
                scale_meters=SCALE_METERS,
                tile_scale=TILE_SCALE,
                extra_property_names=["dataset_type"],
            )

            filename = f"prism_county_daily_{state_abbrev}_{year}_{RUN_TIMESTAMP}"
            task = geeutil.start_export(
                collection=annual_results,
                description=filename,
                drive_folder=DRIVE_FOLDER,
                filename=filename,
                selectors=geeutil.ID_COLS + ["date", "year", "dataset_type"] + BANDS,
            )
            tasks.append(task)

    logging.info("\nMonitoring export progress...")
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
