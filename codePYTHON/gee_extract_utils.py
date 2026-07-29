"""
Shared Earth Engine extraction utilities for the PRISM and ERA5 pipelines.

Factored out of 01_test_prism_extract.py (the validated IL/IN small-scale
test) so the full-scale PRISM (02_extract_prism_county.py) and ERA5
(03_extract_era5_county.py) scripts share one tested implementation of the
dataset-agnostic mechanics:
- Earth Engine auth
- cross-machine path resolution (personal Mac dev repo vs Kodama Ubuntu
  server)
- CONUS county geometry
- per-day county-mean reduction
- export to Drive
- progress-bar monitoring + logging
- simple manifest-based resumability (skip already-completed periods)

Each dataset-specific script supplies only its own config: collection ID,
band list, any band preprocessing (unit conversions, derived bands like
wind speed), and scale/tileScale. Keep this module dataset-agnostic --
anything PRISM- or ERA5-specific belongs in the calling script, not here.
"""

import json
import logging
import time
from datetime import datetime
from pathlib import Path

import ee
from tqdm import tqdm

# ---------------------------------------------------------------------
# Geography
# ---------------------------------------------------------------------

# All CONUS state FIPS codes + DC (48 states + DC = 49 units). Excludes
# AK (02), HI (15), and territories (60, 66, 69, 72, 78) per the
# project's "contiguous United States" scope -- confirm with the PI if
# a different scope is ever needed.
CONUS_STATE_ABBREVIATIONS = {
    "01": "AL", "04": "AZ", "05": "AR", "06": "CA", "08": "CO", "09": "CT",
    "10": "DE", "11": "DC", "12": "FL", "13": "GA", "16": "ID", "17": "IL",
    "18": "IN", "19": "IA", "20": "KS", "21": "KY", "22": "LA", "23": "ME",
    "24": "MD", "25": "MA", "26": "MI", "27": "MN", "28": "MS", "29": "MO",
    "30": "MT", "31": "NE", "32": "NV", "33": "NH", "34": "NJ", "35": "NM",
    "36": "NY", "37": "NC", "38": "ND", "39": "OH", "40": "OK", "41": "OR",
    "42": "PA", "44": "RI", "45": "SC", "46": "SD", "47": "TN", "48": "TX",
    "49": "UT", "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI",
    "56": "WY",
}
CONUS_STATE_FIPS = sorted(CONUS_STATE_ABBREVIATIONS)

COUNTY_COLLECTION = "TIGER/2018/Counties"

# Identifier columns every extraction shares -- keep these column names in
# sync with the "ID_COLS" convention used in 04_aggregate_daily_to_monthly.py.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]


def get_counties(state_fips_list=CONUS_STATE_FIPS, county_collection=COUNTY_COLLECTION):
    """
    Return counties for the given states (defaults to all of CONUS + DC).

    Retains selected identifiers and drops unneeded fields.
    """
    return (
        ee.FeatureCollection(county_collection)
        .filter(ee.Filter.inList("STATEFP", state_fips_list))
        .select(
            propertySelectors=["GEOID", "STATEFP", "COUNTYFP", "NAME"],
            newProperties=["geoid", "state_fips", "county_fips", "county_name"],
        )
    )


def filter_counties_by_state(counties, state_fips):
    """Return only the counties belonging to one state."""
    return counties.filter(ee.Filter.eq("state_fips", state_fips))


# ---------------------------------------------------------------------
# Paths (cross-machine: personal Mac dev repo <-> Kodama Ubuntu server)
# ---------------------------------------------------------------------

def resolve_data_root(candidates):
    """
    Return the first existing directory from `candidates`, in order.

    Mirrors the project's Stata style guide pattern of checking multiple
    candidate roots (C:/Dropbox, D:/Dropbox, /mnt/data_d/Dropbox) so the
    same script's informational messages make sense whether it's run
    from the personal dev repo on a Mac or from Kodama. Raises rather
    than silently defaulting to one, since guessing wrong here means
    telling the user to move files to the wrong place.
    """
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return path

    raise FileNotFoundError(
        "None of the candidate data roots exist on this machine: "
        f"{[str(c) for c in candidates]}. Add this machine's path to the "
        "candidate list in the calling script."
    )


# ---------------------------------------------------------------------
# Earth Engine setup
# ---------------------------------------------------------------------

def initialize_earth_engine(project):
    """Initialize Earth Engine, authenticating only if necessary."""
    try:
        ee.Initialize(project=project)
    except Exception:
        ee.Authenticate()
        ee.Initialize(project=project)

    logging.info("Earth Engine initialized (project=%s).", project)


# ---------------------------------------------------------------------
# Per-image county reduction
# ---------------------------------------------------------------------

def reduce_image_by_county(
    image,
    counties,
    bands,
    scale_meters,
    tile_scale=4,
    extra_property_names=None,
):
    """
    Calculate county-level spatial means for one daily image.

    Each resulting feature represents one county-day. `extra_property_names`
    lets a dataset copy through image-level metadata that varies by
    dataset (e.g. PRISM's 'dataset_type'); pass None/[] for datasets that
    don't have an equivalent (e.g. ERA5).
    """
    image = ee.Image(image)
    extra_property_names = extra_property_names or []

    date = ee.Date(image.get("system:time_start")).format("YYYY-MM-dd")
    year = ee.Date(image.get("system:time_start")).get("year")

    county_stats = image.select(bands).reduceRegions(
        collection=counties,
        reducer=ee.Reducer.mean(),
        scale=scale_meters,
        tileScale=tile_scale,
    )

    def add_fields(feature):
        feature = ee.Feature(feature).set("date", date).set("year", year)
        for prop_name in extra_property_names:
            feature = feature.set(prop_name, image.get(prop_name))
        return feature.setGeometry(None)

    return county_stats.map(add_fields)


def build_period_collection(
    image_collection,
    counties,
    bands,
    scale_meters,
    tile_scale=4,
    extra_property_names=None,
):
    """
    Build a county-day FeatureCollection from an already date-filtered,
    already-preprocessed ImageCollection.

    Any unit conversions or derived bands (e.g. ERA5 Kelvin -> Celsius,
    wind speed from u/v components) should be applied by the caller
    before passing the collection in here -- this function only knows
    how to reduce whatever bands it's given.
    """
    image_collection = image_collection.select(bands)

    nested_results = image_collection.map(
        lambda image: reduce_image_by_county(
            image, counties, bands, scale_meters, tile_scale, extra_property_names
        )
    )

    # map() over an ImageCollection returning FeatureCollections produces a
    # collection of collections; flatten it into one county-day table.
    return ee.FeatureCollection(nested_results).flatten()


# ---------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------

def run_timestamp():
    """Timestamp string for building idempotent, collision-free filenames."""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def start_export(collection, description, drive_folder, filename, selectors):
    """
    Start a CSV export to Google Drive.

    `filename` should already include a run timestamp (see
    `run_timestamp()`) so reruns don't collide with prior exports in
    Drive.
    """
    task = ee.batch.Export.table.toDrive(
        collection=collection,
        description=description,
        folder=drive_folder,
        fileNamePrefix=filename,
        fileFormat="CSV",
        selectors=selectors,
    )

    try:
        task.start()
    except Exception as exc:
        logging.error("Failed to start export task '%s': %s", description, exc)
        raise

    logging.info("Started export '%s'. Task ID: %s", description, task.id)
    return task


# ---------------------------------------------------------------------
# Progress monitoring
# ---------------------------------------------------------------------

def monitor_export_tasks(tasks, poll_interval_seconds=15):
    """
    Poll Earth Engine until all export tasks finish, showing a progress
    bar and logging state transitions (e.g. READY -> RUNNING -> COMPLETED).

    Returns the list of task IDs that did NOT finish as COMPLETED (i.e.
    FAILED or CANCELLED), so the caller can decide not to mark those
    periods complete in the resumability manifest.
    """
    terminal_states = {"COMPLETED", "FAILED", "CANCELLED"}
    remaining = {task.id: task for task in tasks}
    last_seen_state = {task_id: None for task_id in remaining}
    failed_task_ids = []

    with tqdm(total=len(tasks), desc="Exporting", unit="task") as bar:
        while remaining:
            finished_ids = []
            state_counts = {}

            for task_id, task in remaining.items():
                state = task.status()["state"]
                state_counts[state] = state_counts.get(state, 0) + 1

                if state != last_seen_state[task_id]:
                    logging.info(
                        "Task %s: %s -> %s", task_id, last_seen_state[task_id], state
                    )
                    last_seen_state[task_id] = state

                if state in terminal_states:
                    finished_ids.append(task_id)
                    if state != "COMPLETED":
                        failed_task_ids.append(task_id)

            for task_id in finished_ids:
                remaining.pop(task_id)
                bar.update(1)

            status_summary = ", ".join(
                f"{count} {state}" for state, count in state_counts.items()
            )
            bar.set_postfix_str(status_summary or "waiting on status...")
            bar.refresh()

            if remaining:
                time.sleep(poll_interval_seconds)

    if failed_task_ids:
        logging.warning(
            "%d task(s) did not complete successfully: %s",
            len(failed_task_ids),
            failed_task_ids,
        )
    else:
        logging.info("All export tasks completed successfully.")

    return failed_task_ids


# ---------------------------------------------------------------------
# Resumability: track which periods (e.g. years) have already exported
# ---------------------------------------------------------------------
#
# This is deliberately simple: a JSON file listing period keys (e.g.
# "1994") that have already been submitted and completed successfully.
# It only protects against *this script* being restarted -- it doesn't
# inspect Drive/GCS directly. That's a reasonable tradeoff for now: it
# avoids needing separate Drive/GCS API credentials just to check what
# already exists, at the cost of the manifest and the actual exported
# files being able to drift apart if someone deletes a Drive file by
# hand. Worth revisiting if that turns out to be a problem in practice.

def load_completed_periods(manifest_path):
    """Return the set of period keys (e.g. years) already marked complete."""
    manifest_path = Path(manifest_path)
    if not manifest_path.exists():
        return set()
    return set(json.loads(manifest_path.read_text()))


def mark_period_complete(manifest_path, period_key):
    """Append `period_key` to the manifest so a rerun can skip it."""
    manifest_path = Path(manifest_path)
    completed = load_completed_periods(manifest_path)
    completed.add(str(period_key))
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(sorted(completed), indent=2))


# ---------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------

def setup_logging(log_path):
    """
    Configure logging to write to both the console and a persistent file
    at `log_path` -- important for a job that may run unattended on
    Kodama for a long time, where no one is watching the terminal.
    """
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_path),
            logging.StreamHandler(),
        ],
        force=True,
    )
    logging.info("Logging to %s", log_path)
