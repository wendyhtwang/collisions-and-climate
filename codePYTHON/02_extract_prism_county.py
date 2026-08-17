"""
Full-scale PRISM extraction for all CONUS counties, 1981-2025, all 7
PRISM variables, at daily resolution.

- Extracts at DAILY resolution even though the end target is monthly:
  compositing images with .sum()/.mean() before reducing to county means
  was found to shift results ~1-2% from reducing each day independently.
  Monthly aggregation instead happens client-side in
  05_aggregate_daily_to_monthly.py, which is validated correct.
- One Drive export task per calendar year (~45 tasks). A local JSON
  manifest tracks completed years, updated as each task finishes, so a
  rerun skips them.
- Output destination is resolved from a candidate-path list (Kodama path
  first, personal dev repo fallback second), not hardcoded, so the same
  script works on either machine.

"""


import logging
from pathlib import Path

import gee_extract_utils as geeutil

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"

# All 7 PRISM variables listed in Phase 3 of the task doc (the small-scale
# test only used 4 of these -- ppt, tmean, tmin, tmax).
BANDS = ["ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]

# PRISM's nominal pixel size is approximately 4.6 km.
SCALE_METERS = 4638.3
TILE_SCALE = 4

# CHANGE FROM TEST: full CONUS + DC, not just IL/IN.
STATE_FIPS = geeutil.CONUS_STATE_FIPS

# CHANGE FROM TEST: full PRISM period, not just 2020-21. PRISM begins in
# 1981; "end of 2025" per the task doc.
YEARS = list(range(1981, 2026))

DRIVE_FOLDER = "earth_engine_prism_full"

RUN_TIMESTAMP = geeutil.run_timestamp()

# Everything below is bookkeeping local to wherever this script runs from
# (personal repo now, Kodama's shared codePYTHON/ later) -- built off the
# script's own location rather than a hardcoded root, so it doesn't need
# to change when the script moves.
REPO_ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = REPO_ROOT / "dataCSV" / "PRISM"
MANIFEST_PATH = STATE_DIR / "prism_full_completed_years.json"
LOG_PATH = STATE_DIR / "logs" / f"prism_full_extract_{RUN_TIMESTAMP}.log"

# Where the exported CSVs should end up once downloaded/synced from
# Drive -- first existing path wins. Add this machine's path here if
# neither matches (e.g. a different mount point).
MOVE_DESTINATION_CANDIDATES = [
    "/mnt/data_f/AnimalCollisionsWeatherData/PRISM",  # Kodama server
    REPO_ROOT / "dataRAW" / "PRISM",  # personal dev repo fallback
]

# How often to poll Earth Engine for task status. Longer than the test's
# 15s since a 45-task run will take much longer overall and there's no
# need to hammer the API every 15 seconds for hours.
POLL_INTERVAL_SECONDS = 30


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    geeutil.setup_logging(LOG_PATH)
    geeutil.initialize_earth_engine(EE_PROJECT)

    counties = geeutil.get_counties(state_fips_list=STATE_FIPS)

    # Small client-side check -- retrieves metadata only, not the full
    # extraction, so this is cheap even at CONUS scale.
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
        logging.info("Building PRISM extraction for %d...", year)

        image_collection = geeutil.build_year_image_collection(PRISM_COLLECTION, year, BANDS)
        annual_results = geeutil.build_period_collection(
            image_collection=image_collection,
            counties=counties,
            bands=BANDS,
            scale_meters=SCALE_METERS,
            tile_scale=TILE_SCALE,
            extra_property_names=["dataset_type"],
        )

        filename = f"prism_county_daily_{year}_{RUN_TIMESTAMP}"
        export_specs.append(dict(
            collection=annual_results,
            description=filename,
            filename=filename,
            selectors=geeutil.ID_COLS + ["date", "year", "dataset_type"] + BANDS,
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
