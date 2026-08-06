"""
Stage 1 of 2: submit Earth Engine exports for a small, targeted PRISM
county-year-month spot check.

Per Eyal's suggestion (#animal-collisions, 2026-08-06): rather than
comparing PRISM against a different product (NOAA's Climate at a Glance,
which has its own gridding/interpolation and won't match exactly), get GEE
to reproduce a county-year-month panel from the SAME PRISM source for a
subset of counties/years, and compare that to the pipeline's output. Any
gap isolates a processing/aggregation bug rather than a cross-product
methodology difference.

Eventually also want to spot-check the ERA5 county-year-month panel
(dataCSV/ERA5/era5_county_month.csv), once that extraction/aggregation is
complete.

CHANGE (2026-08-06): originally fetched daily rows synchronously via
getInfo() (first per year, then per month after the per-year call timed
out). Both hit Earth Engine's interactive/value:compute endpoint limits --
first "Computation timed out" on a full year (~365 chained reduceRegions
calls), then "User memory limit exceeded" on a single month. Both errors
share one root cause: the synchronous getInfo() endpoint has much tighter
time/memory ceilings than the async batch Export.table.toDrive() endpoint,
even for a workload this small. Rather than keep shrinking the chunk size
(diminishing returns, more round trips, still fragile), this now uses the
same async Export-to-Drive pattern 01_test_prism_extract.py /
02_extract_prism_county.py already use successfully at full-CONUS scale --
one export task per sampled year, submitted here, then downloaded/synced
and aggregated+compared locally by 06b_compare_prism_spotcheck.py.

WORKFLOW:
  1. Run this script. It submits one Drive export task per year in
     SPOT_CHECK_YEARS (small: only the sampled counties, not full CONUS)
     and waits for them to complete.
  2. Sync/download the exported CSVs from Drive folder DRIVE_FOLDER into
     RAW_DAILY_DIR (see path below, also printed at the end of this run).
  3. Run 06b_compare_prism_spotcheck.py, which aggregates those daily
     files to monthly (reusing 04_aggregate_daily_to_monthly.py's own
     logic) and compares them to the production
     dataCSV/PRISM/prism_county_month.csv.

KNOWN OPEN ISSUE -- Wisconsin county duplication:
02c/02d_diagnose_*_proposed.py found 18 WI counties with every daily PRISM
row duplicated (byte-identical) in the 2020/2021 exports; root cause not
confirmed there. This script deliberately FORCE-INCLUDES two of the
affected GEOIDs (55001, 55003), one WI control GEOID (55009), and Marion
County, IL (17121 -- already hand-validated in verify_prism_gee_console.js)
alongside a random sample. NOTE: an actual run of this sampling (Kodama,
2026-08-06) showed 55001 and 55003 EACH appearing as 2 separate county
features in TIGER/2018/Counties itself -- new evidence the duplication
originates in the county source data, not downstream in reduceRegions/
tileScale as 02c's (never-actually-run, per its own docstring) hypothesis
assumed. Worth confirming and flagging back to whoever owns that
diagnostic thread. 06b's aggregation step already tolerates this the same
way production does (drops confirmed byte-identical duplicate rows).

Requires Earth Engine credentials (earthengine-api). Not part of the
numbered pipeline -- run manually whenever the extraction/aggregation code
changes and you want an independent check.
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

# Match 02_extract_prism_county.py exactly -- any difference here would
# make a mismatch ambiguous (real bug vs. different reduction params).
# Eyal's suggestion said "some of the variables" -- trim this list for a
# faster/cheaper run if checking all 7 isn't needed.
BANDS = ["ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]
SCALE_METERS = 4638.3
TILE_SCALE = 4

# --- county sample ---
N_RANDOM_COUNTIES = 10
SAMPLE_SEED = 42  # fixed so reruns pick the same random counties

# Always included regardless of the random sample -- see the "KNOWN OPEN
# ISSUE" note above. Set to [] to sample purely randomly.
FORCE_INCLUDE_GEOIDS = [
    "17121",  # Marion County, IL -- already hand-validated (verify_prism_gee_console.js)
    "55001",  # Adams County, WI -- known duplicated in 2020/2021 exports
    "55003",  # Ashland County, WI -- known duplicated in 2020/2021 exports
    "55009",  # Buffalo County, WI -- WI control, NOT flagged as duplicated
]

# --- years ---
# Spans the PRISM period and includes both years where the WI duplication
# was found (2020, 2021) plus the AN81->AN91 vintage boundary.
SPOT_CHECK_YEARS = [2000, 2010, 2020, 2021, 2025]

# Guardrail so a config typo (e.g. N_RANDOM_COUNTIES=500) doesn't turn this
# into an accidental full-scale run -- raise deliberately if a bigger spot
# check is genuinely wanted. Per CLAUDE.md: don't run large jobs without
# explicit approval.
MAX_COUNTY_YEAR_COMBINATIONS = 150

DRIVE_FOLDER = "earth_engine_prism_spotcheck"
POLL_INTERVAL_SECONDS = 15  # small job -- same as the small-scale 01 test script

# Higher than Earth Engine's default task priority (100) -- the ERA5
# extraction (03_extract_era5_county.py) has a long queue of tasks
# already sitting at the default 100, and this spot check is small and
# meant to be checked quickly, not wait behind that queue. Only has an
# effect on projects registered for paid Earth Engine access -- if
# "collisions-and-climate" isn't one, this is silently a no-op and these
# tasks will queue normally behind the ERA5 ones. See start_export()'s
# docstring in gee_extract_utils.py.
TASK_PRIORITY = 500

RUN_TIMESTAMP = geeutil.run_timestamp()
REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check"
LOG_PATH = OUTPUT_DIR / "logs" / f"prism_spotcheck_extract_{RUN_TIMESTAMP}.log"

# Where to sync/move the exported CSVs after this script finishes --
# 06b_compare_prism_spotcheck.py reads from here.
RAW_DAILY_DIR = OUTPUT_DIR / "raw_daily"


# ---------------------------------------------------------------------
# County sample
# ---------------------------------------------------------------------

def build_county_sample(counties):
    """
    Return a FeatureCollection of FORCE_INCLUDE_GEOIDS plus
    N_RANDOM_COUNTIES more, chosen via a seeded
    ee.FeatureCollection.randomColumn() so reruns are reproducible.
    """
    forced = counties.filter(ee.Filter.inList("geoid", FORCE_INCLUDE_GEOIDS))

    remaining = counties.filter(ee.Filter.inList("geoid", FORCE_INCLUDE_GEOIDS).Not())
    random_sample = (
        remaining.randomColumn("rand", seed=SAMPLE_SEED)
        .sort("rand")
        .limit(N_RANDOM_COUNTIES)
    )

    return forced.merge(random_sample)


# ---------------------------------------------------------------------
# PRISM-specific: build one year's image collection (same as
# 02_extract_prism_county.py)
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
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    geeutil.setup_logging(LOG_PATH)
    geeutil.initialize_earth_engine(EE_PROJECT)

    n_combinations = (N_RANDOM_COUNTIES + len(FORCE_INCLUDE_GEOIDS)) * len(SPOT_CHECK_YEARS)
    if n_combinations > MAX_COUNTY_YEAR_COMBINATIONS:
        raise ValueError(
            f"{n_combinations} county-year combinations requested, over the "
            f"{MAX_COUNTY_YEAR_COMBINATIONS} guardrail -- this script is meant "
            "for a small spot check, not a full-scale extraction. Reduce "
            "N_RANDOM_COUNTIES/SPOT_CHECK_YEARS, or raise "
            "MAX_COUNTY_YEAR_COMBINATIONS deliberately if a bigger spot "
            "check is genuinely wanted."
        )

    all_counties = geeutil.get_counties()
    sampled_counties = build_county_sample(all_counties)

    sampled_geoids = sorted(sampled_counties.aggregate_array("geoid").getInfo())
    logging.info(
        "Spot-checking %d county-feature(s) x %d years (%s) -- GEOIDs: %s",
        len(sampled_geoids), len(SPOT_CHECK_YEARS), SPOT_CHECK_YEARS, sampled_geoids,
    )

    export_specs = []
    for year in SPOT_CHECK_YEARS:
        image_collection = build_year_image_collection(year)
        annual_results = geeutil.build_period_collection(
            image_collection=image_collection,
            counties=sampled_counties,
            bands=BANDS,
            scale_meters=SCALE_METERS,
            tile_scale=TILE_SCALE,
            extra_property_names=["dataset_type"],
        )

        filename = f"prism_spotcheck_daily_{year}_{RUN_TIMESTAMP}"
        export_specs.append(dict(
            collection=annual_results,
            description=filename,
            filename=filename,
            selectors=geeutil.ID_COLS + ["date", "year", "dataset_type"] + BANDS,
            priority=TASK_PRIORITY,
        ))

    # Same shared-folder submission helper 02_extract_prism_county.py uses,
    # to avoid the duplicate-Drive-folder race described in its docstring.
    tasks = geeutil.start_exports_to_shared_folder(export_specs, drive_folder=DRIVE_FOLDER)

    logging.info("Monitoring %d export task(s)...", len(tasks))
    failed_task_ids = geeutil.monitor_export_tasks(tasks, poll_interval_seconds=POLL_INTERVAL_SECONDS)

    if failed_task_ids:
        logging.warning(
            "%d export task(s) did not complete successfully -- rerun this "
            "script to retry: %s", len(failed_task_ids), failed_task_ids,
        )
    else:
        logging.info("All export tasks completed successfully.")

    RAW_DAILY_DIR.mkdir(parents=True, exist_ok=True)
    logging.info(
        "\nNext steps:\n"
        "  1. Sync/download the exported CSVs from Drive folder '%s' into:\n"
        "       %s\n"
        "  2. Run 06b_compare_prism_spotcheck.py to aggregate and compare "
        "against production.",
        DRIVE_FOLDER, RAW_DAILY_DIR,
    )


if __name__ == "__main__":
    main()
