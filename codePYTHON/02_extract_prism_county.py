"""
Full-scale PRISM extraction: CONUS, 1981-2025, county mean, all 7 bands.

Extracts daily county-level mean PRISM weather values for:
- All CONUS counties (48 states + DC; excludes AK, HI, territories)
- 1981-01-01 through 2025-12-31 (45 calendar years)
- All 7 PRISM variables Phase 3 asks for: ppt, tmean, tmin, tmax, tdmean,
  vpdmin, vpdmax

This is the full-scale generalization of 01_test_prism_extract.py (which
validated the method against the GEE console for IL/IN, 2020-21). The
mechanics (auth, county reduction, export, progress monitoring, logging,
resumability) live in gee_extract_utils.py, shared with
03_extract_era5_county.py.

One export task per calendar year (~45 tasks total), each a Drive CSV
named prism_county_daily_<year>_<run_timestamp>.csv. After each run,
completed years are recorded in a local manifest (see MANIFEST_PATH)
so a restart -- e.g. after this is moved to run on Kodama -- skips
years already done instead of re-submitting them.

Deliberately kept at DAILY resolution (like the test), even though the
end target is county-year-month: the Earth Engine console spot-check
during the small-scale test showed that compositing an ImageCollection
with .sum()/.mean() before reduceRegions gives numbers off by ~1-2% from
summing/averaging independently-reduced daily values (root cause not yet
diagnosed -- see chat history). Until that's resolved, monthly
aggregation happens client-side in 04_aggregate_daily_to_monthly.py,
which is already validated correct, rather than risking the same
discrepancy silently across 45 years of production data.

Note: this is a large job (45 export tasks, full CONUS, ~3100
counties x ~365 days x 7 bands per year). Per CLAUDE.md, do not run this
against the full YEARS range without explicit sign-off -- consider
testing with a 1-2 year YEARS range first.

Google Drive folder: earth_engine_prism_full
After completion, sync/move the CSVs to:
  Kodama: /mnt/data_f/AnimalCollisionsWeatherData/PRISM
  (personal dev repo fallback: dataRAW/PRISM)
"""

import logging
from pathlib import Path

import ee

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
STATE_DIR = REPO_ROOT / "dataBUILD" / "PRISM"
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
# PRISM-specific: build one year's image collection
# ---------------------------------------------------------------------

def build_year_image_collection(year):
    """Return the PRISM ImageCollection for one calendar year, band-selected."""
    start_date = ee.Date.fromYMD(year, 1, 1)
    end_date = start_date.advance(1, "year")

    return (
        ee.ImageCollection(PRISM_COLLECTION)
        .filterDate(start_date, end_date)
        .select(BANDS)
    )


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

    # CHANGE: build all export specs first, without submitting, then hand
    # them to start_exports_to_shared_folder() so the first task's Drive
    # folder is confirmed to exist before the rest are submitted -- see
    # that function's docstring for why submitting them all back-to-back
    # (the old behavior) risks creating duplicate same-named Drive
    # folders instead of reusing one.
    export_specs = []
    spec_years = []

    for year in years_to_run:
        logging.info("Building PRISM extraction for %d...", year)

        image_collection = build_year_image_collection(year)
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
