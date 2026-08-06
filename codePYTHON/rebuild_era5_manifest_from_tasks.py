"""
Rebuild dataCSV/ERA5/era5_full_completed_years.json (the resumability
manifest 03_extract_era5_county.py reads) from Earth Engine's own task
history, and optionally cancel any still-pending/running tasks from that
run.

WHY THIS EXISTS: 03_extract_era5_county.py only writes its manifest AFTER
monitor_export_tasks() returns, which requires ALL submitted tasks to
reach a terminal state -- it is NOT written incrementally as each year
finishes. If the local Python process is killed/closed before every task
finishes (e.g. the terminal was closed with 16/45 years still
running/queued), the manifest never gets written at all, even for years
that already completed successfully server-side. Rerunning
03_extract_era5_county.py in that state would re-submit ALL 45 years
(duplicate exports for the 29 already done), since it has no manifest to
check against yet.

This script queries Earth Engine directly for the real state of every
era5_county_daily_* task -- Earth Engine tracks batch tasks server-side,
independent of whether the submitting script is still running, same as
reattach_monitor.py relies on -- and:
  1. Marks every COMPLETED year as done in the manifest, so a plain rerun
     of 03_extract_era5_county.py (unmodified) will skip them.
  2. Reports which years are still RUNNING/READY (i.e. the ones you'd
     need to cancel before rerunning 03, so it doesn't duplicate them).
  3. With --cancel-pending, also cancels those still-running/queued tasks.
     Default is OFF (report only) -- cancelling is a real action against
     live Earth Engine infrastructure, even though it's reversible by
     just resubmitting.

Usage:
    python rebuild_era5_manifest_from_tasks.py                   # report only
    python rebuild_era5_manifest_from_tasks.py --cancel-pending  # also cancel

Alternative to --cancel-pending: cancel the pending tasks by hand in the
GEE Tasks panel -> Task Manager (search "era5_county_daily"), then rerun
this script without the flag to rebuild the manifest from the resulting
state.
"""

import argparse
import logging
import re
from pathlib import Path

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"

# Must match 03_extract_era5_county.py's filename convention exactly:
# era5_county_daily_<year>_<run_timestamp>
DESCRIPTION_RE = re.compile(r"^era5_county_daily_(\d{4})_")

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "era5_full_completed_years.json"


def find_era5_full_tasks():
    """
    Return {year: (task, status_dict)} for every era5_county_daily_* task
    found via Task.list(). If a year was submitted more than once (e.g. a
    prior partial rerun), prefer a COMPLETED task for that year over any
    other state, so a stale FAILED/CANCELLED duplicate can't shadow a
    real completed export.
    """
    all_tasks = ee.batch.Task.list()

    by_year = {}
    for task in all_tasks:
        status = task.status()
        match = DESCRIPTION_RE.match(status.get("description", ""))
        if not match:
            continue

        year = int(match.group(1))
        existing = by_year.get(year)
        if existing is None:
            by_year[year] = (task, status)
        elif status["state"] == "COMPLETED" and existing[1]["state"] != "COMPLETED":
            by_year[year] = (task, status)

    return by_year


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cancel-pending", action="store_true",
        help="Also cancel any still-running/queued era5_county_daily_* tasks found.",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    geeutil.initialize_earth_engine(EE_PROJECT)

    by_year = find_era5_full_tasks()
    if not by_year:
        raise SystemExit(
            "No era5_county_daily_* tasks found via Task.list() -- nothing to do."
        )

    completed_years = []
    pending = []  # (year, task, state)

    for year, (task, status) in sorted(by_year.items()):
        state = status["state"]
        if state == "COMPLETED":
            completed_years.append(year)
        elif state in ("FAILED", "CANCELLED"):
            logging.warning(
                "Year %d's most recent task is %s (task ID %s) -- NOT marked "
                "complete; will be re-submitted on the next 03 run.",
                year, state, task.id,
            )
        else:
            pending.append((year, task, state))

    logging.info(
        "%d year(s) COMPLETED, %d year(s) still pending (RUNNING/READY/etc.), "
        "out of %d task(s) found.",
        len(completed_years), len(pending), len(by_year),
    )

    for year in completed_years:
        geeutil.mark_period_complete(MANIFEST_PATH, year)
    logging.info(
        "Manifest at %s now has %d completed year(s): %s",
        MANIFEST_PATH, len(completed_years), sorted(completed_years),
    )

    if pending:
        pending_years = sorted(y for y, _, _ in pending)
        logging.info("Still pending (not yet in manifest): %s", pending_years)

        if args.cancel_pending:
            for year, task, state in pending:
                logging.info("Cancelling year %d (task %s, state=%s)...", year, task.id, state)
                task.cancel()
            logging.info(
                "Cancelled %d task(s). Rerun 03_extract_era5_county.py "
                "(unmodified) to re-submit exactly these %d year(s) -- the "
                "manifest now correctly skips the %d already-completed year(s).",
                len(pending), len(pending), len(completed_years),
            )
        else:
            logging.info(
                "Not cancelling (pass --cancel-pending to do so, or cancel "
                "by hand in the GEE Tasks panel / Task Manager first). Once "
                "cancelled, just rerun 03_extract_era5_county.py unmodified "
                "-- it will skip the %d completed year(s) already in the "
                "manifest and re-submit only the %d pending one(s).",
                len(completed_years), len(pending),
            )
    else:
        logging.info(
            "No pending tasks found -- rerun 03_extract_era5_county.py "
            "unmodified if any years are still missing from the manifest."
        )


if __name__ == "__main__":
    main()
