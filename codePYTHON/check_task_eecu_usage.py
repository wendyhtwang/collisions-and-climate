"""
Check actual (not extrapolated) EECU-second usage for completed/running
Earth Engine tasks, and project what that implies for a larger run against
the Contributor tier's monthly quota.

The `batch_eecu_usage_seconds` field remains queryable on a task's status
after it reaches COMPLETED, so this works even after the script/monitor
that originally submitted the tasks has already exited.

Usage:
    python check_task_eecu_usage.py --years-in-run N --project-years N TASK_ID [TASK_ID ...]

Example -- the 2020+2021 CONUS PRISM validation run:
    python check_task_eecu_usage.py --years-in-run 2 --project-years 45 \\
        3W3WEDYKGITNBGFVTDYKID74 ZTZL5GOK3UVRO73RPHM5G5DN
"""

import argparse
import logging

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"

# Contributor tier: 1,000 EECU-hours/month, per
# https://developers.google.com/earth-engine/guides/noncommercial_tiers
CONTRIBUTOR_TIER_MONTHLY_EECU_SECONDS = 1_000 * 3600
PARTNER_TIER_MONTHLY_EECU_SECONDS = 100_000 * 3600


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_ids", nargs="+", help="Task IDs to check.")
    parser.add_argument(
        "--years-in-run", type=int, default=1,
        help="How many calendar years these task(s) cover, for the per-year rate.",
    )
    parser.add_argument(
        "--project-years", type=int, default=45,
        help="How many years to project the cost out to (default: full 1981-2025 run).",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    geeutil.initialize_earth_engine(EE_PROJECT)

    tasks = geeutil.attach_to_tasks(args.task_ids)
    if not tasks:
        raise SystemExit("None of the given task IDs were found via Task.list().")

    total_eecu_seconds = 0.0
    for task in tasks:
        status = task.status()
        eecu = status.get("batch_eecu_usage_seconds", 0) or 0
        print(f"{task.id}: state={status['state']}, eecu_seconds={eecu:,.0f}")
        total_eecu_seconds += eecu

    per_year = total_eecu_seconds / args.years_in_run
    projected = per_year * args.project_years

    print(f"\nTotal EECU-seconds for {args.years_in_run} year(s): {total_eecu_seconds:,.0f}")
    print(f"Per-year average: {per_year:,.0f} EECU-seconds")
    print(
        f"Projected for {args.project_years} years: {projected:,.0f} EECU-seconds "
        f"({projected / 3600:,.1f} EECU-hours)"
    )
    print(
        f"Contributor tier monthly cap: {CONTRIBUTOR_TIER_MONTHLY_EECU_SECONDS:,} EECU-seconds "
        f"(1,000 EECU-hours) -- projected usage: "
        f"{projected / CONTRIBUTOR_TIER_MONTHLY_EECU_SECONDS * 100:.0f}% of that"
    )
    print(
        f"Partner tier monthly cap: {PARTNER_TIER_MONTHLY_EECU_SECONDS:,} EECU-seconds "
        f"(100,000 EECU-hours) -- projected usage: "
        f"{projected / PARTNER_TIER_MONTHLY_EECU_SECONDS * 100:.1f}% of that"
    )


if __name__ == "__main__":
    main()
