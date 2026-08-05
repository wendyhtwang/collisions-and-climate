"""
PROPOSED / NOT YET RUN -- diagnostic only, follow-up to
02g_diagnose_get_counties_full_audit_proposed.py.

02f found 2 features for each of the 18 previously-known-affected GEOIDs
in geeutil.get_counties()'s output (checked via a filtered subset of 23
GEOIDs). 02g, run moments later against the SAME get_counties() call,
found zero duplicates anywhere in the full ~3,108-feature collection
(total feature count == distinct geoid count). Both scripts' logic holds
up on inspection -- neither has an obvious bug -- so the leading
explanation is that the duplication is NOT a fixed, deterministic
property of the county data or a specific code path, but something that
varies between Earth Engine calls (e.g. an artifact of the distributed
backend's retry/materialization behavior, not something reproducible
from the client side).

This matters a lot for how to proceed: everything from 02c through 02g
implicitly assumed the duplication was stable and specific to these 18
counties -- worth fixing once, in one place. If it's actually
intermittent, a fix aimed narrowly at "these 18 GEOIDs" or at
get_counties()'s filter/select chain may not be the right target, and no
single getInfo() call (including the diagnostics already run) can be
fully trusted as ground truth in isolation.

This script tests that directly: runs the SAME get_counties() ->
per-GEOID count check N times in a row within a single script execution,
and reports whether the affected/control GEOIDs' counts are stable
across repetitions or vary from call to call. Stable counts (2 every
time for affected, 1 every time for control) would argue against pure
randomness and point back toward something deterministic that 02g's
different query shape (aggregate_array/distinct vs filter/getInfo)
simply doesn't trigger. Varying counts would support the non-determinism
hypothesis directly.

Read-only getInfo() calls only -- doesn't export or write anything.
Cheap: each repetition only touches the same 23-GEOID subset used in
02c/02d/02f, not the full collection.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"
N_REPETITIONS = 5

AFFECTED_GEOIDS = [
    "55001", "55003", "55005", "55007", "55023", "55041", "55065", "55067",
    "55085", "55095", "55113", "55119", "55121", "55123", "55125", "55129",
    "55135", "55137",
]
CONTROL_GEOIDS = ["55009", "55011", "55013", "55015", "55017"]


def count_by_geoid_once(geoids):
    """Fresh get_counties() call + filter + getInfo(), same as 02f."""
    counties = geeutil.get_counties()
    subset = counties.filter(ee.Filter.inList("geoid", geoids))
    features = subset.getInfo()["features"]
    counts = {}
    for f in features:
        geoid = f["properties"]["geoid"]
        counts[geoid] = counts.get(geoid, 0) + 1
    return counts


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    all_geoids = AFFECTED_GEOIDS + CONTROL_GEOIDS
    history = {geoid: [] for geoid in all_geoids}

    for run in range(1, N_REPETITIONS + 1):
        print(f"Run {run}/{N_REPETITIONS}...")
        counts = count_by_geoid_once(all_geoids)
        for geoid in all_geoids:
            history[geoid].append(counts.get(geoid, 0))

    print("\ngeoid       group      counts across runs         stable?")
    any_unstable = False
    for geoid in all_geoids:
        group = "affected" if geoid in AFFECTED_GEOIDS else "control "
        counts = history[geoid]
        stable = len(set(counts)) == 1
        if not stable:
            any_unstable = True
        print(f"  {geoid}  {group}  {counts}  {'yes' if stable else 'NO -- VARIES'}")

    print()
    if any_unstable:
        print(
            "At least one GEOID's count varied across repeated, "
            "otherwise-identical calls -- supports the non-determinism "
            "hypothesis. This changes the fix strategy: rather than "
            "targeting specific GEOIDs or a specific code path, the "
            "aggregation pipeline needs to keep treating duplicate-row "
            "detection as a per-run safety check (which "
            "04_aggregate_daily_to_monthly.py already does) rather than "
            "assuming a one-time upstream fix eliminates the issue "
            "permanently."
        )
    else:
        print(
            "All GEOIDs' counts were stable across all "
            f"{N_REPETITIONS} runs -- this argues AGAINST pure "
            "randomness and contradicts 02g's clean result. Worth "
            "re-running 02g itself a couple more times before concluding "
            "anything -- it's possible 02g's aggregate_array/distinct "
            "approach is the one giving an unreliable answer, not the "
            "per-GEOID filter approach used here and in 02f."
        )


if __name__ == "__main__":
    main()
