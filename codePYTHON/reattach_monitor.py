"""
Reattach the (upgraded) progress-bar monitor to already-submitted Earth
Engine export tasks, without resubmitting them.

Use this to get better live monitoring (EECU-seconds used, per-task
running time -- not just a state label) for tasks that are already
running server-side in Earth Engine, from a *second* terminal, while
whatever originally submitted them keeps running undisturbed. Also
useful if the original script was interrupted: Ctrl+C stops the local
Python process, but does NOT cancel the Earth Engine batch task itself
(only task.cancel() or the GEE Tasks tab does that) -- so the task is
still out there running and can be reattached to instead of resubmitted.

Usage:
    python reattach_monitor.py TASK_ID [TASK_ID ...]

Task IDs are printed in the original script's log output, e.g.:
    Started export 'prism_county_daily_2020_...'. Task ID: 3W3WEDYKGITNBGFVTDYKID74
"""

import logging
import sys

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(1)

    task_ids = sys.argv[1:]

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    geeutil.initialize_earth_engine(EE_PROJECT)

    tasks = geeutil.attach_to_tasks(task_ids)
    if not tasks:
        logging.error("None of the given task IDs were found via Task.list().")
        raise SystemExit(1)

    logging.info("Reattached to %d task(s): %s", len(tasks), [t.id for t in tasks])
    geeutil.monitor_export_tasks(tasks, poll_interval_seconds=30)


if __name__ == "__main__":
    main()
